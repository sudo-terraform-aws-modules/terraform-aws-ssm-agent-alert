import boto3
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

GRACE_PERIOD_MINUTES = int(os.environ.get("INITIALIZATION_GRACE_PERIOD_MINUTES", "5"))


def lambda_handler(event, context):
    ssm = boto3.client("ssm")
    ec2 = boto3.client("ec2")
    sns = boto3.client("sns")
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]
    region = os.environ.get("AWS_REGION", "unknown")
    account_id = context.invoked_function_arn.split(":")[4]

    # Collect all ConnectionLost instances across all pages
    paginator = ssm.get_paginator("describe_instance_information")
    connection_lost = []

    for page in paginator.paginate(
        Filters=[{"Key": "PingStatus", "Values": ["ConnectionLost"]}]
    ):
        connection_lost.extend(page["InstanceInformationList"])

    if not connection_lost:
        logger.info("All SSM agents are online. No alerts needed.")
        return

    logger.info("Found %d instance(s) with ConnectionLost status.", len(connection_lost))

    for ssm_info in connection_lost:
        instance_id = ssm_info["InstanceId"]

        try:
            ec2_response = ec2.describe_instances(InstanceIds=[instance_id])
        except Exception as exc:
            logger.error("Error describing instance %s: %s", instance_id, exc)
            continue

        reservations = ec2_response.get("Reservations", [])
        if not reservations:
            logger.info("Instance %s not found in EC2 — skipping.", instance_id)
            continue

        instance = reservations[0]["Instances"][0]
        state = instance["State"]["Name"]

        if state != "running":
            logger.info(
                "Instance %s is %s — skipping alert (intentional shutdown).",
                instance_id, state,
            )
            continue

        # Skip alert if instance is still within the boot grace period
        launch_time = instance["LaunchTime"]
        age_minutes = (datetime.now(timezone.utc) - launch_time).total_seconds() / 60

        if age_minutes < GRACE_PERIOD_MINUTES:
            logger.info(
                "Instance %s launched %.1f min ago (grace period: %d min) — skipping.",
                instance_id, age_minutes, GRACE_PERIOD_MINUTES,
            )
            continue

        instance_name = next(
            (tag["Value"] for tag in instance.get("Tags", []) if tag["Key"] == "Name"),
            instance_id,
        )

        last_ping = ssm_info.get("LastPingDateTime") or "Unknown"
        if hasattr(last_ping, "strftime"):
            last_ping = last_ping.strftime("%Y-%m-%d %H:%M:%S UTC")

        message = "\n".join([
            "ALERT: SSM Agent is OFFLINE on a RUNNING EC2 instance.",
            "",
            f"Instance ID:    {instance_id}",
            f"Instance Name:  {instance_name}",
            f"Instance State: {state}",
            f"Last SSM Ping:  {last_ping}",
            f"Account ID:     {account_id}",
            f"Region:         {region}",
            "",
            "Action Required: The SSM Agent is not responding on a running instance.",
            "Please check the SSM Agent service and instance connectivity.",
        ])

        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"[SSM Alert] Agent Offline — {instance_name} ({instance_id})",
            Message=message,
        )

        logger.info("Alert sent for instance %s (%s).", instance_id, instance_name)

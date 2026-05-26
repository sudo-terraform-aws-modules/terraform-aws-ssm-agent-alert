# terraform-module-ssm-ping-alert

A reusable Terraform module that sets up automated alerting when an EC2 instance's SSM Agent goes offline while the instance is still running. Deploy it into any customer AWS account by sourcing it from a caller directory.

## Architecture

```
EventBridge Rule (every 5 minutes)
        │
        ▼
  AWS Lambda
  - calls ssm:DescribeInstanceInformation
  - finds all instances where PingStatus = ConnectionLost
  - cross-checks with EC2: is the instance actually running?
  - skips instances within the boot grace period
        │
        ├── running + ConnectionLost → ALERT
        └── stopped / terminated    → skip (intentional shutdown)
        │
        ▼
  Amazon SNS → Email
```

## Prerequisites

- Your AWS CLI must be authenticated to the customer account via role-based access before running Terraform.
- The `TF_VAR_alert_email` environment variable must be exported before running Terraform.
- After `terraform apply`, the Sudo alert email subscriber must click the **Confirm subscription** link in the AWS confirmation email.

## Usage

Edit `terraform.tfvars` in your caller directory with the customer values, export the email, then run Terraform.

```bash
export TF_VAR_alert_email="support@sudoconsultants.com"
terraform init
terraform plan
terraform apply
```

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the full step-by-step deployment guide.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Short identifier for the customer. Used as a prefix for all resource names. Lowercase letters, numbers, and hyphens only. | `string` | — | yes |
| `alert_email` | Sudo Consultants alert email subscribed to the SNS topic. Pass via `TF_VAR_alert_email`. | `string` | — | yes |
| `schedule_expression` | How often EventBridge triggers Lambda to poll SSM ping status. | `string` | `"rate(5 minutes)"` | no |
| `initialization_grace_period_minutes` | Minutes after instance launch before alerting on missing SSM Agent. Prevents false alerts during boot. | `number` | `5` | no |
| `lambda_timeout_seconds` | Maximum seconds Lambda is allowed to run. | `number` | `15` | no |
| `lambda_memory_mb` | Memory allocated to Lambda in MB. | `number` | `128` | no |
| `tags` | Additional tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arn` | ARN of the SNS alert topic. |
| `sns_topic_name` | Name of the SNS alert topic. |
| `lambda_function_arn` | ARN of the validator Lambda function. |
| `lambda_function_name` | Name of the validator Lambda function. |
| `eventbridge_rule_name` | Name of the EventBridge scheduled rule. |
| `eventbridge_rule_arn` | ARN of the EventBridge scheduled rule. |

## How it works

1. **EventBridge** fires every 5 minutes (configurable) and invokes the Lambda function.
2. **Lambda** calls `ssm:DescribeInstanceInformation` filtering for `PingStatus = ConnectionLost` to get all instances where the SSM agent is offline.
3. For each offline instance, Lambda calls `ec2:DescribeInstances` to check the actual EC2 state:
   - `stopped` or `terminated` → intentional shutdown, no alert.
   - launched less than 5 minutes ago → still booting, no alert.
   - `running` + SSM offline → genuine problem, send alert.
4. **SNS** sends an email with the instance ID, name, last SSM ping time, account, and region.

## File structure

```plaintext
terraform-module-ssm-ping-alert/
├── .github/
│   └── workflows/
│       └── main.yml
├── lambda/
│   └── ssm_agent_validator.py  # Python 3.12 Lambda source
├── docs/
│   └── DEPLOYMENT.md           # Full deployment guide
├── .gitignore
├── .pre-commit-config.yaml
├── LICENSE
├── main.tf                     # All AWS resources
├── outputs.tf                  # Module outputs
├── README.md
├── variables.tf                # Variable definitions
└── versions.tf                 # Terraform and provider version constraints
```

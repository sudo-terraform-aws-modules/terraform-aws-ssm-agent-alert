locals {
  name_prefix = "${var.project_name}-ssm-ping-alert"
  common_tags = merge(var.tags, {
    Module   = "ssm-ping-alert"
    Project = var.project_name
  })
}

# ─── SNS Topic ────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "this" {
  name = "${local.name_prefix}-topic"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "sudo_support" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─── IAM Role for Lambda ──────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:DescribeInstanceInformation"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

# ─── Lambda Function ──────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/ssm_agent_validator.py"
  output_path = "${path.root}/lambda/ssm_agent_validator.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = "${local.name_prefix}-validator"
  role             = aws_iam_role.lambda.arn
  handler          = "ssm_agent_validator.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb

  environment {
    variables = {
      SNS_TOPIC_ARN                       = aws_sns_topic.this.arn
      INITIALIZATION_GRACE_PERIOD_MINUTES = tostring(var.initialization_grace_period_minutes)
    }
  }

  tags = local.common_tags
}

# ─── EventBridge Scheduled Rule → Lambda ─────────────────────────────────────

resource "aws_cloudwatch_event_rule" "ssm_ping_check" {
  name                = "${local.name_prefix}-ping-check"
  description         = "Polls Lambda every ${var.schedule_expression} to check SSM agent ping status across all instances."
  schedule_expression = var.schedule_expression

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.ssm_ping_check.name
  target_id = "SSMAgentValidatorLambda"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ssm_ping_check.arn
}

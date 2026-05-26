output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives SSM agent offline alerts."
  value       = aws_sns_topic.this.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.this.name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that checks SSM agent ping status."
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge scheduled rule that triggers Lambda."
  value       = aws_cloudwatch_event_rule.ssm_ping_check.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge scheduled rule."
  value       = aws_cloudwatch_event_rule.ssm_ping_check.arn
}

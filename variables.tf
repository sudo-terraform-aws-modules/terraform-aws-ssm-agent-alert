variable "project_name" {
  description = "Short identifier for the project. Used in resource naming (e.g. 'acme', 'globex'). Lowercase letters, numbers, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "alert_email" {
  description = "Pass the email address via TF_VAR_alert_email environment variable — do not hardcode in any file."
  type        = string
  sensitive   = true
}

variable "schedule_expression" {
  description = "How often EventBridge triggers the Lambda to poll SSM ping status. Uses AWS rate or cron syntax."
  type        = string
  default     = "rate(5 minutes)"
}

variable "initialization_grace_period_minutes" {
  description = "Minutes to wait after an instance launches before alerting on a missing SSM Agent. Prevents false alerts during OS boot and SSM Agent startup."
  type        = number
  default     = 5

  validation {
    condition     = var.initialization_grace_period_minutes >= 0
    error_message = "initialization_grace_period_minutes must be 0 or greater."
  }
}

variable "lambda_timeout_seconds" {
  description = "Maximum seconds the Lambda function is allowed to run. Increase if you have a large number of instances to check."
  type        = number
  default     = 15

  validation {
    condition     = var.lambda_timeout_seconds >= 3 && var.lambda_timeout_seconds <= 900
    error_message = "lambda_timeout_seconds must be between 3 and 900."
  }
}

variable "lambda_memory_mb" {
  description = "Memory allocated to the Lambda function in MB. Higher memory also means more CPU shares, which speeds up API calls."
  type        = number
  default     = 128

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "lambda_memory_mb must be between 128 and 10240."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

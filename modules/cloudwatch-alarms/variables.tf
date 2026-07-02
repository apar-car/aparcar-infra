variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aparcar"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alarm notifications"
  type        = string
  sensitive   = true
}

variable "lambda_function_name" {
  description = "Lambda function name to monitor"
  type        = string
}

variable "dlq_name" {
  description = "SQS DLQ name to monitor"
  type        = string
}

variable "appsync_api_id" {
  description = "AppSync API ID to monitor"
  type        = string
}

variable "lambda_timeout_ms" {
  description = "Lambda timeout in milliseconds (for duration alarm threshold)"
  type        = number
  default     = 25000
}

variable "lambda_concurrent_executions_threshold" {
  description = "Concurrent executions alarm threshold"
  type        = number
  default     = 8
}

variable "appsync_latency_threshold_ms" {
  description = "AppSync p99 latency alarm threshold in milliseconds"
  type        = number
  default     = 3000
}

variable "appsync_4xx_threshold" {
  description = "AppSync 4XX error count threshold per 5 minutes"
  type        = number
  default     = 5
}
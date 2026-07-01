variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aparcar"
}

variable "leave_signal_handler_arn" {
  description = "ARN of the leave-signal-handler Lambda function"
  type        = string
}

variable "parking_signals_table_arn" {
  description = "ARN of the parking signals DynamoDB table"
  type        = string
}

variable "parking_signals_table_name" {
  description = "Name of the parking signals DynamoDB table"
  type        = string
}

variable "api_key_expiry_days" {
  description = "Number of days until API key expires"
  type        = number
  default     = 365
}
variable "slack_webhook_url" {
  description = "Slack webhook URL for CloudWatch alarm notifications"
  type        = string
  sensitive   = true
}

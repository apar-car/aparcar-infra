variable "environment" {
  type = string
}

variable "project" {
  type    = string
  default = "aparcar"
}

variable "appsync_api_arn" {
  description = "AppSync API ARN to associate with WAF"
  type        = string
}

variable "rate_limit" {
  description = "Max requests per 5 minutes per IP"
  type        = number
  default     = 100
}


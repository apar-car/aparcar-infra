variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aparcar"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "apar-car"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "aparcar-infra"
}

variable "account_id" {
  description = "AWS account ID for this environment"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "aparcar-terraform-state-022079552075"
}

variable "lock_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = "aparcar-terraform-locks"
}

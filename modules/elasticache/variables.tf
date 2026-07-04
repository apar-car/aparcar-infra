variable "environment" {
  type = string
}

variable "project" {
  type    = string 
  default = "aparcar"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  type        = list(string) 
  description = "Security group IDs allowed to connect to Redis"
  default     = []
}
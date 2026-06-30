variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "aparcar"
}

variable "ttl_attribute" {
  description = "TTL attribute name"
  type        = string
  default     = "ttl"
}

variable "additional_attributes" {
  description = "Additional attributes for GSIs"
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "global_secondary_indexes" {
  description = "Global secondary indexes"
  type = list(object({
    name               = string
    hash_name          = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
  }))
  default = []
}
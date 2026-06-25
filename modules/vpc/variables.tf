variable "environment" {
    description = "Environment name (dev, staging, prod)"
    type        = string
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
}

variable "private_subnet_cidrs" {
    description = "List of private subnets CIDRS"
    type        = list(string)
}

variable "public_subnet_cidrs" {
    description = "List of public subnet CIDRs"
    type        = list(string)
    default     = []
}

variable "availability_zones" {
    description = "List of availability zones"
    type        = list(string)
}

variable "project" {
    description = "Project name"
    type        = string
    default     = "aparcar"
}

variable "enable_nat_gateway" {
    description = "Enable NAT Gateway (false for dev to save cost)"
    type        = bool
    default     = false
}


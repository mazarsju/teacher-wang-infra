variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "environment must be lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "project_name" {
  description = "Short project name used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "project_name must be lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones for public/private subnets (minimum 2)"
  type        = number

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 for multi-AZ networking."
  }
}

variable "enable_nat_gateway" {
  description = "Create a single NAT Gateway for private subnet outbound internet (~$32/mo + data). Disable until EKS/RDS need egress to save cost."
  type        = bool
}

variable "additional_tags" {
  description = "Extra tags merged onto taggable resources (on top of provider default_tags)"
  type        = map(string)
  default     = {}
}


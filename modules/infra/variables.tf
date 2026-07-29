variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project name used for resource naming"
  type        = string
  default     = "teacher-wang"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones for public/private subnets (minimum 2)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 for multi-AZ networking."
  }
}

variable "enable_nat_gateway" {
  description = "Create a single NAT Gateway for private subnet outbound internet (~$32/mo + data). Disable until EKS/RDS need egress to save cost."
  type        = bool
  default     = true
}


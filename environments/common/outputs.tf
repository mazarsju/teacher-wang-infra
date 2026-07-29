# Shared defaults for every environment root (prod, and later staging / dev).
# Consumed as a module — not a Terraform root you apply directly.

output "project_name" {
  description = "Short project name used for resource naming"
  value       = "teacher-wang"
}

output "aws_region" {
  description = "Default AWS region"
  value       = "eu-west-1"
}

output "az_count" {
  description = "Default number of availability zones"
  value       = 2
}

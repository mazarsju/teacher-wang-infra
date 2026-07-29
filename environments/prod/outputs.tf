output "aws_account_id" {
  description = "AWS account ID used by the current credentials"
  value       = module.infra.aws_account_id
}

output "aws_caller_arn" {
  description = "ARN of the IAM principal Terraform is authenticated as"
  value       = module.infra.aws_caller_arn
}

output "aws_region" {
  description = "Effective AWS region"
  value       = module.infra.aws_region
}

output "terraform_state_bucket" {
  description = "S3 bucket used for Terraform remote state and native lock files"
  value       = module.infra.terraform_state_bucket
}

output "vpc_id" {
  description = "ID of the application VPC"
  value       = module.infra.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the application VPC"
  value       = module.infra.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets (one per AZ)"
  value       = module.infra.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets (one per AZ)"
  value       = module.infra.private_subnet_ids
}

output "availability_zones" {
  description = "Availability zones used by the VPC subnets"
  value       = module.infra.availability_zones
}

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway"
  value       = module.infra.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID of the single NAT Gateway (null when enable_nat_gateway is false)"
  value       = module.infra.nat_gateway_id
}

output "public_route_table_id" {
  description = "ID of the public route table (IGW default route)"
  value       = module.infra.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the shared private route table (NAT default route when enabled)"
  value       = module.infra.private_route_table_id
}

output "alb_security_group_id" {
  description = "Baseline security group for the public ALB"
  value       = module.infra.alb_security_group_id
}

output "app_security_group_id" {
  description = "Baseline security group for private application workloads"
  value       = module.infra.app_security_group_id
}

output "db_security_group_id" {
  description = "Baseline security group for RDS PostgreSQL"
  value       = module.infra.db_security_group_id
}

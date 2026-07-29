output "aws_account_id" {
  description = "AWS account ID used by the current credentials"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "ARN of the IAM principal Terraform is authenticated as"
  value       = data.aws_caller_identity.current.arn
}

output "aws_region" {
  description = "Effective AWS region"
  value       = data.aws_region.current.name
}

output "terraform_state_bucket" {
  description = "S3 bucket used for Terraform remote state and native lock files"
  value       = aws_s3_bucket.terraform_state.id
}

output "vpc_id" {
  description = "ID of the application VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the application VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (one per AZ)"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones used by the VPC subnets"
  value       = local.azs
}


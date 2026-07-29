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

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the single NAT Gateway (null when enable_nat_gateway is false)"
  value       = try(aws_nat_gateway.main[0].id, null)
}

output "public_route_table_id" {
  description = "ID of the public route table (IGW default route)"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the shared private route table (NAT default route when enabled)"
  value       = aws_route_table.private.id
}

output "alb_security_group_id" {
  description = "Baseline security group for the public ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Baseline security group for private application workloads"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Baseline security group for RDS PostgreSQL"
  value       = aws_security_group.db.id
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS hostname"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Initial PostgreSQL database name"
  value       = aws_db_instance.main.db_name
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN for the RDS-managed master password"
  value       = try(aws_db_instance.main.master_user_secret[0].secret_arn, null)
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for the backend image"
  value       = aws_ecr_repository.app["backend"].repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for the frontend image"
  value       = aws_ecr_repository.app["frontend"].repository_url
}

output "ecr_backend_repository_arn" {
  description = "ECR repository ARN for the backend image"
  value       = aws_ecr_repository.app["backend"].arn
}

output "ecr_frontend_repository_arn" {
  description = "ECR repository ARN for the frontend image"
  value       = aws_ecr_repository.app["frontend"].arn
}

output "ecr_registry_id" {
  description = "AWS account ID of the ECR registry"
  value       = aws_ecr_repository.app["backend"].registry_id
}

output "ecs_enabled" {
  description = "Whether the ECS cluster and capacity are provisioned"
  value       = var.enable_ecs
}

output "ecs_cluster_name" {
  description = "ECS cluster name (null when enable_ecs is false)"
  value       = try(aws_ecs_cluster.main[0].name, null)
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN (null when enable_ecs is false)"
  value       = try(aws_ecs_cluster.main[0].arn, null)
}

output "ecs_capacity_provider_name" {
  description = "ECS EC2 capacity provider name (null when enable_ecs is false)"
  value       = try(aws_ecs_capacity_provider.ec2[0].name, null)
}

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution / ECR pulls (null when enable_ecs is false)"
  value       = try(aws_iam_role.ecs_task_execution[0].arn, null)
}

output "ecs_autoscaling_group_name" {
  description = "Autoscaling group for ECS container instances (null when enable_ecs is false)"
  value       = try(aws_autoscaling_group.ecs[0].name, null)
}


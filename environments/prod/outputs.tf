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

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.infra.db_instance_id
}

output "db_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = module.infra.db_endpoint
}

output "db_address" {
  description = "RDS hostname"
  value       = module.infra.db_address
}

output "db_port" {
  description = "RDS port"
  value       = module.infra.db_port
}

output "db_name" {
  description = "Initial PostgreSQL database name"
  value       = module.infra.db_name
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN for the RDS-managed master password"
  value       = module.infra.db_master_user_secret_arn
  sensitive   = true
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for the backend image"
  value       = module.infra.ecr_backend_repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for the frontend image"
  value       = module.infra.ecr_frontend_repository_url
}

output "ecr_backend_repository_arn" {
  description = "ECR repository ARN for the backend image"
  value       = module.infra.ecr_backend_repository_arn
}

output "ecr_frontend_repository_arn" {
  description = "ECR repository ARN for the frontend image"
  value       = module.infra.ecr_frontend_repository_arn
}

output "ecr_registry_id" {
  description = "AWS account ID of the ECR registry"
  value       = module.infra.ecr_registry_id
}

output "ecs_enabled" {
  description = "Whether the ECS cluster and capacity are provisioned"
  value       = module.infra.ecs_enabled
}

output "ecs_cluster_name" {
  description = "ECS cluster name (null when enable_ecs is false)"
  value       = module.infra.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN (null when enable_ecs is false)"
  value       = module.infra.ecs_cluster_arn
}

output "ecs_capacity_provider_name" {
  description = "ECS EC2 capacity provider name (null when enable_ecs is false)"
  value       = module.infra.ecs_capacity_provider_name
}

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution / ECR pulls (null when enable_ecs is false)"
  value       = module.infra.ecs_task_execution_role_arn
}

output "ecs_autoscaling_group_name" {
  description = "Autoscaling group for ECS container instances (null when enable_ecs is false)"
  value       = module.infra.ecs_autoscaling_group_name
}

output "ecs_backend_service_name" {
  description = "ECS backend service name (null when enable_ecs is false)"
  value       = module.infra.ecs_backend_service_name
}

output "ecs_frontend_service_name" {
  description = "ECS frontend service name (null when enable_ecs is false)"
  value       = module.infra.ecs_frontend_service_name
}

output "ecs_backend_task_definition_arn" {
  description = "Backend task definition ARN (null when enable_ecs is false)"
  value       = module.infra.ecs_backend_task_definition_arn
}

output "ecs_frontend_task_definition_arn" {
  description = "Frontend task definition ARN (null when enable_ecs is false)"
  value       = module.infra.ecs_frontend_task_definition_arn
}

output "ecs_backend_log_group_name" {
  description = "CloudWatch log group for backend tasks (null when enable_ecs is false)"
  value       = module.infra.ecs_backend_log_group_name
}

output "ecs_frontend_log_group_name" {
  description = "CloudWatch log group for frontend tasks (null when enable_ecs is false)"
  value       = module.infra.ecs_frontend_log_group_name
}

output "alb_arn" {
  description = "Public ALB ARN (null when enable_ecs is false)"
  value       = module.infra.alb_arn
}

output "alb_dns_name" {
  description = "Public ALB DNS name for the frontend (null when enable_ecs is false)"
  value       = module.infra.alb_dns_name
}

output "alb_zone_id" {
  description = "Public ALB Route 53 zone ID (null when enable_ecs is false)"
  value       = module.infra.alb_zone_id
}

output "alb_frontend_target_group_arn" {
  description = "Frontend target group ARN (null when enable_ecs is false)"
  value       = module.infra.alb_frontend_target_group_arn
}

output "alb_https_enabled" {
  description = "True when the ALB has an HTTPS listener"
  value       = module.infra.alb_https_enabled
}

output "alb_https_url" {
  description = "Public HTTPS URL (https://teacherwang.xyz when ECS + domain are on)"
  value       = module.infra.alb_https_url
}

output "alb_acm_certificate_arn" {
  description = "ACM certificate ARN for teacherwang.xyz"
  value       = module.infra.alb_acm_certificate_arn
}

output "alb_domain_name" {
  description = "Configured public domain"
  value       = module.infra.alb_domain_name
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = module.infra.route53_zone_id
}

output "route53_name_servers" {
  description = "Set these nameservers in Namecheap (Custom DNS) for teacherwang.xyz"
  value       = module.infra.route53_name_servers
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.infra.cognito_user_pool_id
}

output "cognito_app_client_id" {
  description = "Cognito app client ID (public; no secret)"
  value       = module.infra.cognito_app_client_id
}

output "cognito_issuer" {
  description = "OIDC issuer URL for JWT verification"
  value       = module.infra.cognito_issuer
}

output "cognito_domain" {
  description = "Cognito Hosted UI domain prefix"
  value       = module.infra.cognito_domain
}

output "cognito_hosted_ui_base_url" {
  description = "Cognito Hosted UI / OAuth base URL (use …/oauth2/idpresponse as Google redirect)"
  value       = module.infra.cognito_hosted_ui_base_url
}

output "cognito_google_enabled" {
  description = "True when Google IdP is attached to the user pool"
  value       = module.infra.cognito_google_enabled
}

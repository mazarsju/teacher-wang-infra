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

output "ecs_backend_service_name" {
  description = "ECS backend service name (null when enable_ecs is false)"
  value       = try(aws_ecs_service.backend[0].name, null)
}

output "ecs_frontend_service_name" {
  description = "ECS frontend service name (null when enable_ecs is false)"
  value       = try(aws_ecs_service.frontend[0].name, null)
}

output "ecs_backend_task_definition_arn" {
  description = "Backend task definition ARN (null when enable_ecs is false)"
  value       = try(aws_ecs_task_definition.backend[0].arn, null)
}

output "ecs_frontend_task_definition_arn" {
  description = "Frontend task definition ARN (null when enable_ecs is false)"
  value       = try(aws_ecs_task_definition.frontend[0].arn, null)
}

output "ecs_backend_log_group_name" {
  description = "CloudWatch log group for backend tasks (null when enable_ecs is false)"
  value       = try(aws_cloudwatch_log_group.ecs_backend[0].name, null)
}

output "ecs_frontend_log_group_name" {
  description = "CloudWatch log group for frontend tasks (null when enable_ecs is false)"
  value       = try(aws_cloudwatch_log_group.ecs_frontend[0].name, null)
}

output "alb_arn" {
  description = "Public ALB ARN (null when enable_ecs is false)"
  value       = try(aws_lb.app[0].arn, null)
}

output "alb_dns_name" {
  description = "Public ALB DNS name for the frontend (null when enable_ecs is false)"
  value       = try(aws_lb.app[0].dns_name, null)
}

output "alb_zone_id" {
  description = "Public ALB Route 53 zone ID (null when enable_ecs is false)"
  value       = try(aws_lb.app[0].zone_id, null)
}

output "alb_frontend_target_group_arn" {
  description = "Frontend target group ARN (null when enable_ecs is false)"
  value       = try(aws_lb_target_group.frontend[0].arn, null)
}

output "alb_https_enabled" {
  description = "True when the ALB has an HTTPS listener (ECS on + alb_domain_name set)"
  value       = local.alb_https_enabled
}

output "alb_https_url" {
  description = "Public HTTPS URL when domain + ECS are configured (null otherwise)"
  value       = local.alb_https_enabled ? "https://${var.alb_domain_name}" : null
}

output "alb_acm_certificate_arn" {
  description = "ACM certificate ARN for the ALB domain (null when alb_domain_name is unset)"
  value       = try(aws_acm_certificate.alb[0].arn, null)
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (null when CloudFront is off)"
  value       = try(aws_cloudfront_distribution.app[0].id, null)
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (null when CloudFront is off)"
  value       = try(aws_cloudfront_distribution.app[0].domain_name, null)
}

output "cloudfront_maintenance_bucket" {
  description = "S3 bucket for the deploy maintenance page (null when CloudFront is off)"
  value       = try(aws_s3_bucket.maintenance[0].id, null)
}

output "conversation_logs_bucket" {
  description = "S3 bucket for per-user chat transcripts"
  value       = aws_s3_bucket.conversation_logs.id
}

output "conversation_logs_bucket_arn" {
  description = "ARN of the conversation-logs S3 bucket"
  value       = aws_s3_bucket.conversation_logs.arn
}

output "cloudfront_acm_certificate_arn" {
  description = "us-east-1 ACM certificate ARN used by CloudFront (null when off)"
  value       = try(aws_acm_certificate.cloudfront[0].arn, null)
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID for alb_domain_name (null when unset)"
  value       = try(aws_route53_zone.app[0].zone_id, null)
}

output "route53_name_servers" {
  description = "Route 53 name servers — set these in Namecheap Custom DNS (null when no domain)"
  value       = try(aws_route53_zone.app[0].name_servers, null)
}

output "alb_domain_name" {
  description = "Configured public domain (null when unset)"
  value       = var.alb_domain_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint hostname"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_app_client_id" {
  description = "Cognito app client ID (public SPA client; no secret)"
  value       = aws_cognito_user_pool_client.app.id
}

output "cognito_issuer" {
  description = "OIDC issuer URL for JWT verification"
  value       = local.cognito_issuer
}

output "cognito_domain" {
  description = "Cognito Hosted UI domain prefix"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_hosted_ui_base_url" {
  description = "Base URL for Cognito Hosted UI / OAuth"
  value       = local.cognito_hosted_ui_base_url
}

output "cognito_google_redirect_uri" {
  description = "Authorized redirect URI to paste into the Google Cloud OAuth Web client"
  value       = local.cognito_google_redirect_uri
}

output "cognito_google_enabled" {
  description = "True when the Google identity provider is configured on the user pool"
  # Derive from the resource, not from sensitive client secret locals (avoids tainting).
  value = length(aws_cognito_identity_provider.google) > 0
}

output "cognito_google_secret_arn" {
  description = "Secrets Manager ARN for Google OAuth creds when seeded via TF_VAR (null otherwise)"
  value       = try(aws_secretsmanager_secret.cognito_google[0].arn, null)
}

output "cognito_pre_signup_lambda_name" {
  description = "Pre Sign-up Lambda that enforces unique email and links Google SSO to existing users"
  value       = aws_lambda_function.cognito_pre_signup.function_name
}


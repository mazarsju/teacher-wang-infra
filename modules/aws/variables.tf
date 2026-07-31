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
  description = "Create a single NAT Gateway for private subnet outbound internet (~$32/mo + data). Not required for ECS on public subnets."
  type        = bool
}

variable "enable_ecs" {
  description = "Provision ECS cluster + EC2 Spot capacity (~instance cost only; ECS control plane is free). Set false when idle."
  type        = bool
  default     = false
}

variable "ecs_instance_type" {
  description = "EC2 instance type for the ECS capacity provider (prefer t4g.* for ARM cost)"
  type        = string
  default     = "t4g.small"
}

variable "ecs_use_spot" {
  description = "Use Spot instances for ECS capacity (cheaper; can be interrupted)"
  type        = bool
  default     = true
}

variable "ecs_desired_capacity" {
  description = "Desired number of ECS container instances (one is enough for frontend + backend)"
  type        = number
  default     = 1
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS container instances"
  type        = number
  default     = 0
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS container instances"
  type        = number
  default     = 2
}

variable "ecs_instance_disk_size_gb" {
  description = "Root volume size (GiB) for each ECS container instance"
  type        = number
  default     = 30
}

variable "ecs_image_tag" {
  description = "Image tag to deploy from ECR for both services"
  type        = string
  default     = "latest"
}

variable "ecs_backend_cpu" {
  description = "CPU units for the backend task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "ecs_backend_memory" {
  description = "Memory (MiB) for the backend task"
  type        = number
  default     = 512
}

variable "ecs_frontend_cpu" {
  description = "CPU units for the frontend task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_frontend_memory" {
  description = "Memory (MiB) for the frontend task"
  type        = number
  default     = 256
}

variable "ecs_backend_container_port" {
  description = "Container port exposed by the backend image"
  type        = number
  default     = 5000
}

variable "ecs_backend_host_port" {
  description = "Host port on the ECS instance mapped to the backend container"
  type        = number
  default     = 5000
}

variable "ecs_frontend_container_port" {
  description = "Container port exposed by the frontend image"
  type        = number
  default     = 80
}

variable "ecs_frontend_host_port" {
  description = "Host port on the ECS instance mapped to the frontend container"
  type        = number
  default     = 8080
}

variable "ecs_backend_desired_count" {
  description = "Initial desired count for the backend ECS service"
  type        = number
  default     = 1
}

variable "ecs_frontend_desired_count" {
  description = "Initial desired count for the frontend ECS service"
  type        = number
  default     = 1
}

variable "ecs_log_retention_days" {
  description = "CloudWatch Logs retention for ECS task logs (shorter = cheaper)"
  type        = number
  default     = 7
}

variable "alb_frontend_health_check_path" {
  description = "HTTP health check path for the frontend target group (app serves GET /health from nginx)"
  type        = string
  default     = "/health"
}

variable "alb_domain_name" {
  description = "Apex domain for the public site (e.g. teacherwang.xyz). Creates Route 53 zone + ACM; enables HTTPS on the ALB when enable_ecs is true. Null skips DNS/TLS."
  type        = string
  default     = null

  validation {
    condition     = var.alb_domain_name == null || can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.alb_domain_name))
    error_message = "alb_domain_name must be a lowercase FQDN (e.g. teacherwang.xyz) or null."
  }
}

variable "cognito_callback_urls" {
  description = "Additional OAuth callback URLs for the Cognito app client (localhost defaults included for Vite)"
  type        = list(string)
  default = [
    "http://localhost:5173/",
    "http://localhost:5173/login",
  ]
}

variable "cognito_logout_urls" {
  description = "Additional OAuth logout URLs for the Cognito app client"
  type        = list(string)
  default = [
    "http://localhost:5173/",
    "http://localhost:5173/login",
  ]
}

variable "cognito_google_client_id" {
  description = "Google OAuth 2.0 Web client ID for Cognito federation. Null skips Google IdP (unless cognito_google_oauth_secret_arn is set)."
  type        = string
  default     = null
}

variable "cognito_google_client_secret" {
  description = "Google OAuth 2.0 Web client secret for Cognito federation. Null skips Google IdP (unless cognito_google_oauth_secret_arn is set)."
  type        = string
  default     = null
  sensitive   = true
}

variable "cognito_google_oauth_secret_arn" {
  description = "Optional Secrets Manager secret ARN with JSON {\"client_id\":\"...\",\"client_secret\":\"...\"} for Cognito Google IdP. Alternative to TF_VAR client id/secret."
  type        = string
  default     = null
}

variable "additional_tags" {
  description = "Extra tags merged onto taggable resources (on top of provider default_tags)"
  type        = map(string)
  default     = {}
}

variable "db_instance_class" {
  description = "RDS instance class (prefer db.t4g.micro for lowest cost)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage in GiB (gp3)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage_gb" {
  description = "Autoscale storage ceiling in GiB (0 disables autoscaling)"
  type        = number
  default     = 0
}

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "teacherwang"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "teacherwang"
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days (0 disables; free-tier accounts often max at 1)"
  type        = number
  default     = 1
}

variable "db_deletion_protection" {
  description = "When true, block delete and require a final snapshot"
  type        = bool
  default     = false
}


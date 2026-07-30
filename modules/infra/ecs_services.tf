# ECS task definitions + services for backend and frontend.
#
# Cost notes:
# - Tasks run on the existing Spot EC2 capacity (no Fargate charge).
# - CloudWatch Logs retention kept short (default 7 days).
# - Push linux/arm64 images to ECR before (or right after) enabling services;
#   otherwise tasks stay in a pull/start failure loop.
# - ALB wiring: public ALB forwards only to the frontend; backend stays VPC-local.

locals {
  ecs_backend_image  = "${aws_ecr_repository.app["backend"].repository_url}:${var.ecs_image_tag}"
  ecs_frontend_image = "${aws_ecr_repository.app["frontend"].repository_url}:${var.ecs_image_tag}"

  ecs_db_password_secret_arn = try(
    "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::",
    null
  )
}

resource "aws_cloudwatch_log_group" "ecs_backend" {
  count = var.enable_ecs ? 1 : 0

  name              = "/ecs/${local.name_prefix}/backend"
  retention_in_days = var.ecs_log_retention_days

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-backend-logs"
    Tier = "private"
  })
}

resource "aws_cloudwatch_log_group" "ecs_frontend" {
  count = var.enable_ecs ? 1 : 0

  name              = "/ecs/${local.name_prefix}/frontend"
  retention_in_days = var.ecs_log_retention_days

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-frontend-logs"
    Tier = "private"
  })
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  count = var.enable_ecs ? 1 : 0

  statement {
    sid     = "ReadRdsMasterSecret"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_db_instance.main.master_user_secret[0].secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = var.enable_ecs ? 1 : 0

  name   = "${local.name_prefix}-ecs-exec-secrets"
  role   = aws_iam_role.ecs_task_execution[0].id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets[0].json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  count = var.enable_ecs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Application task role (expand later for S3, etc.). Distinct from execution role.
resource "aws_iam_role" "ecs_task" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume[0].json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-ecs-task"
    Tier = "private"
  })
}

resource "aws_ecs_task_definition" "backend" {
  count = var.enable_ecs ? 1 : 0

  family                   = "${local.name_prefix}-backend"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task[0].arn
  cpu                      = var.ecs_backend_cpu
  memory                   = var.ecs_backend_memory

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = local.ecs_backend_image
      essential = true

      portMappings = [
        {
          containerPort = var.ecs_backend_container_port
          hostPort      = var.ecs_backend_host_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.main.port) },
        { name = "DB_NAME", value = aws_db_instance.main.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "COGNITO_REGION", value = var.aws_region },
        { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
        { name = "COGNITO_APP_CLIENT_ID", value = aws_cognito_user_pool_client.app.id },
        { name = "COGNITO_ISSUER", value = local.cognito_issuer },
      ]

      secrets = local.ecs_db_password_secret_arn == null ? [] : [
        {
          name      = "DB_PASSWORD"
          valueFrom = local.ecs_db_password_secret_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-backend"
    Tier = "private"
  })
}

resource "aws_ecs_task_definition" "frontend" {
  count = var.enable_ecs ? 1 : 0

  family                   = "${local.name_prefix}-frontend"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task[0].arn
  cpu                      = var.ecs_frontend_cpu
  memory                   = var.ecs_frontend_memory

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = local.ecs_frontend_image
      essential = true

      portMappings = [
        {
          containerPort = var.ecs_frontend_container_port
          hostPort      = var.ecs_frontend_host_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        # Same-host Docker bridge gateway → backend host port (not public).
        # Prefer an nginx/Caddy reverse-proxy /api → this upstream so the browser
        # never talks to the backend directly.
        { name = "BACKEND_UPSTREAM", value = "http://172.17.0.1:${var.ecs_backend_host_port}" },
        # Public Cognito ids for a future SPA login (Vite may need build-time inject).
        { name = "COGNITO_REGION", value = var.aws_region },
        { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
        { name = "COGNITO_APP_CLIENT_ID", value = aws_cognito_user_pool_client.app.id },
        { name = "COGNITO_DOMAIN", value = aws_cognito_user_pool_domain.main.domain },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_frontend[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-frontend"
    Tier = "private"
  })
}

resource "aws_ecs_service" "backend" {
  count = var.enable_ecs ? 1 : 0

  name            = "${local.name_prefix}-backend"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.backend[0].arn
  desired_count   = var.ecs_backend_desired_count

  # Single-instance deploys: allow draining to 0 before starting the replacement.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # Avoid delete waiters timing out while ECS is still DRAINING; a timed-out
  # delete leaves the name reserved and blocks the next CreateService.
  force_delete = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    weight            = 1
    base              = 1
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  timeouts {
    delete = "45m"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-backend"
    Tier = "private"
  })

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_iam_role_policy.ecs_task_execution_secrets,
  ]
}

resource "aws_ecs_service" "frontend" {
  count = var.enable_ecs ? 1 : 0

  name            = "${local.name_prefix}-frontend"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.frontend[0].arn
  desired_count   = var.ecs_frontend_desired_count

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # Same as backend: force past stuck DRAINING so the fixed service name can be reused.
  force_delete = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    weight            = 1
    base              = 0
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend[0].arn
    container_name   = "frontend"
    container_port   = var.ecs_frontend_container_port
  }

  timeouts {
    delete = "45m"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-frontend"
    Tier = "private"
  })

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_lb_listener.http,
    aws_lb_listener.https,
  ]
}

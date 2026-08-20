# One-shot ECS job: same backend image as the Flask service, different command.
# No host port mapping — would collide with the running backend on :5000.
# EventBridge Scheduler is billed per invocation; weekly is free-tier noise.

resource "aws_cloudwatch_log_group" "weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  name              = "/ecs/${local.name_prefix}/weekly-articles"
  retention_in_days = var.ecs_log_retention_days

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-weekly-articles-logs"
    Tier = "private"
  })
}

resource "aws_ecs_task_definition" "weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  family                   = "${local.name_prefix}-weekly-articles"
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
      name      = "weekly-articles"
      image     = local.ecs_backend_image
      essential = true
      command   = ["python3", "-m", "backend.jobs.generate_weekly_articles"]

      environment = local.ecs_backend_environment
      secrets     = local.ecs_backend_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.weekly_articles[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "weekly-articles"
        }
      }
    }
  ])

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-weekly-articles"
    Tier = "private"
  })
}

data "aws_iam_policy_document" "scheduler_weekly_articles_assume" {
  count = var.enable_ecs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scheduler_weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  statement {
    sid       = "RunWeeklyArticlesTask"
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.weekly_articles[0].arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.main[0].arn]
    }
  }

  statement {
    sid     = "PassEcsRoles"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution[0].arn,
      aws_iam_role.ecs_task[0].arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "TagRunTask"
    actions   = ["ecs:TagResource"]
    resources = ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task/${aws_ecs_cluster.main[0].name}/*"]
  }
}

resource "aws_iam_role" "scheduler_weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-weekly-articles-sched"
  assume_role_policy = data.aws_iam_policy_document.scheduler_weekly_articles_assume[0].json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-weekly-articles-sched"
    Tier = "private"
  })
}

resource "aws_iam_role_policy" "scheduler_weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  name   = "${local.name_prefix}-weekly-articles-sched"
  role   = aws_iam_role.scheduler_weekly_articles[0].id
  policy = data.aws_iam_policy_document.scheduler_weekly_articles[0].json
}

resource "aws_scheduler_schedule" "weekly_articles" {
  count = var.enable_ecs ? 1 : 0

  name                         = "${local.name_prefix}-weekly-articles"
  group_name                   = "default"
  description                  = "Run generate_weekly_articles every Monday 08:00 UTC"
  schedule_expression          = "cron(0 8 ? * MON *)"
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.main[0].arn
    role_arn = aws_iam_role.scheduler_weekly_articles[0].arn

    ecs_parameters {
      task_definition_arn     = aws_ecs_task_definition.weekly_articles[0].arn
      task_count              = 1
      enable_ecs_managed_tags = true
      propagate_tags          = "TASK_DEFINITION"

      capacity_provider_strategy {
        capacity_provider = aws_ecs_capacity_provider.ec2[0].name
        weight            = 1
        base              = 0
      }
    }

    retry_policy {
      maximum_retry_attempts = 2
    }
  }

  depends_on = [aws_iam_role_policy.scheduler_weekly_articles]
}

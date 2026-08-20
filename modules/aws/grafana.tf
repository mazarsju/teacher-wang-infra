# Private Grafana OSS on the existing ECS host — CloudWatch Logs + metrics only.
#
# Cost: no extra EC2/ALB; shares the t4g.small with frontend/backend. Reach via
# SSM port-forward to host :3000 (same pattern as RDS). Grafana image from
# Docker Hub (no ECR). Logs Insights scans are ~$0.005/GB.
#
# Security: not on the ALB; no SG ingress on :3000. Dedicated task role (read-only
# CloudWatch/Logs) — do not reuse ecs_task (S3 writes + Cognito admin).

locals {
  # Minimal CloudWatch DS. Skip defaultLogGroups — nested list YAML is easy to
  # break and Grafana exits on parse errors (SSM then sees "destination port failed").
  # Pick log groups in Explore: /ecs/.../backend, /frontend, cognito-pre-signup.
  grafana_datasource_yaml = <<-EOT
    apiVersion: 1
    datasources:
      - name: CloudWatch
        type: cloudwatch
        access: proxy
        isDefault: true
        editable: false
        jsonData:
          authType: default
          defaultRegion: ${var.aws_region}
  EOT

  grafana_start_command = join("\n", [
    "mkdir -p /tmp/grafana/provisioning/datasources /tmp/grafana/provisioning/dashboards /tmp/grafana/provisioning/notifiers /tmp/grafana/provisioning/plugins /tmp/grafana/provisioning/alerting",
    "cat > /tmp/grafana/provisioning/datasources/cloudwatch.yaml <<'GRAFANA_DS_EOF'",
    trimspace(local.grafana_datasource_yaml),
    "GRAFANA_DS_EOF",
    "exec /run.sh",
  ])
}

resource "random_password" "grafana_admin" {
  count = var.enable_ecs ? 1 : 0

  length  = 24
  special = false
}

resource "aws_cloudwatch_log_group" "grafana" {
  count = var.enable_ecs ? 1 : 0

  name              = "/ecs/${local.name_prefix}/grafana"
  retention_in_days = var.ecs_log_retention_days

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-grafana-logs"
    Tier = "private"
  })
}

data "aws_iam_policy_document" "grafana_task" {
  count = var.enable_ecs ? 1 : 0

  statement {
    sid = "CloudWatchMetricsRead"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LogsDescribe"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LogsRead"
    actions = [
      "logs:GetLogEvents",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "logs:StopQuery",
    ]
    resources = [
      aws_cloudwatch_log_group.ecs_backend[0].arn,
      "${aws_cloudwatch_log_group.ecs_backend[0].arn}:*",
      aws_cloudwatch_log_group.ecs_frontend[0].arn,
      "${aws_cloudwatch_log_group.ecs_frontend[0].arn}:*",
      aws_cloudwatch_log_group.cognito_pre_signup.arn,
      "${aws_cloudwatch_log_group.cognito_pre_signup.arn}:*",
      aws_cloudwatch_log_group.grafana[0].arn,
      "${aws_cloudwatch_log_group.grafana[0].arn}:*",
    ]
  }
}

resource "aws_iam_role" "grafana_task" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-grafana-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume[0].json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-grafana-task"
    Tier = "private"
  })
}

resource "aws_iam_role_policy" "grafana_task" {
  count = var.enable_ecs ? 1 : 0

  name   = "${local.name_prefix}-grafana-cloudwatch"
  role   = aws_iam_role.grafana_task[0].id
  policy = data.aws_iam_policy_document.grafana_task[0].json
}

resource "aws_ecs_task_definition" "grafana" {
  count = var.enable_ecs ? 1 : 0

  family                   = "${local.name_prefix}-grafana"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.grafana_task[0].arn
  cpu                      = var.ecs_grafana_cpu
  memory                   = var.ecs_grafana_memory

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = var.ecs_grafana_image
      essential = true

      entryPoint = ["/bin/sh", "-ec"]
      command    = [local.grafana_start_command]

      portMappings = [
        {
          containerPort = var.ecs_grafana_container_port
          hostPort      = var.ecs_grafana_host_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = random_password.grafana_admin[0].result },
        { name = "GF_USERS_ALLOW_SIGN_UP", value = "false" },
        { name = "GF_AUTH_ANONYMOUS_ENABLED", value = "false" },
        { name = "GF_SERVER_HTTP_PORT", value = tostring(var.ecs_grafana_container_port) },
        { name = "GF_PATHS_PROVISIONING", value = "/tmp/grafana/provisioning" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-grafana"
    Tier = "private"
  })
}

resource "aws_ecs_service" "grafana" {
  count = var.enable_ecs ? 1 : 0

  name            = "${local.name_prefix}-grafana"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.grafana[0].arn
  desired_count   = var.ecs_grafana_desired_count

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  force_delete                       = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2[0].name
    weight            = 1
    base              = 0
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  timeouts {
    delete = "45m"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-grafana"
    Tier = "private"
  })

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
  ]
}

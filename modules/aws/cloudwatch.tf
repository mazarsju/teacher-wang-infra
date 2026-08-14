# Global system health dashboard: traffic/errors/latency at the ALB, ECS
# compute for both services, and RDS. All metrics are free defaults (no
# Container Insights, no enhanced RDS monitoring) so this adds no ingestion cost.
#
# ALB metrics are on the frontend target group — the ALB only fronts the
# frontend (backend is VPC-local, see ecs_services.tf) — but they're the best
# available proxy for user-facing traffic health.

resource "aws_cloudwatch_dashboard" "system_status" {
  count = var.enable_ecs ? 1 : 0

  dashboard_name = "${local.name_prefix}-system-status"

  dashboard_body = jsonencode({
    widgets = [
      # --- Traffic ---
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Requests per Hour"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Successful Requests per Hour (by status class)"
          view   = "timeSeries"
          region = var.aws_region
          period = 3600
          yAxis = {
            left = { min = 0, max = 100 }
          }
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { id = "requests", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { id = "c2xx", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { id = "c4xx", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { id = "c5xx", stat = "Sum", visible = false }],
            [{ expression = "100*(c2xx/requests)", label = "2xx %", id = "e2xx" }],
            [{ expression = "100*(c4xx/requests)", label = "4xx %", id = "e4xx" }],
            [{ expression = "100*(c5xx/requests)", label = "5xx %", id = "e5xx" }]
          ]
        }
      },
      # --- Latency & availability ---
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Request Latency"
          view   = "timeSeries"
          region = var.aws_region
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { stat = "Average", label = "Avg latency" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { stat = "p99", label = "p99 latency" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Target Health"
          view   = "timeSeries"
          region = var.aws_region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { stat = "Minimum", label = "Healthy hosts" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.app[0].arn_suffix, "TargetGroup", aws_lb_target_group.frontend[0].arn_suffix, { stat = "Maximum", label = "Unhealthy hosts" }]
          ]
        }
      },
      # --- ECS compute ---
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", aws_ecs_service.backend[0].name, { label = "backend" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", aws_ecs_service.frontend[0].name, { label = "frontend" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "ECS Memory Utilization"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", aws_ecs_service.backend[0].name, { label = "backend" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main[0].name, "ServiceName", aws_ecs_service.frontend[0].name, { label = "frontend" }]
          ]
        }
      },
      # --- Database ---
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 8
        height = 6
        properties = {
          title  = "RDS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 18
        width  = 8
        height = 6
        properties = {
          title  = "RDS Free Storage Space"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 18
        width  = 8
        height = 6
        properties = {
          title  = "RDS Connections"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
        }
      }
    ]
  })
}

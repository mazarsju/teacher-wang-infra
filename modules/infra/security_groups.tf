# Security group baselines for ALB → app → DB traffic.
#
# Cost: security groups are free.
# Naming: AWS `name` and Name tag use the same value ({name_prefix}-{role}).
#
# Ingress model:
# - ALB: 80/443 from the internet
# - App: frontend host port from ALB only; backend host port from the app SG (VPC-local)
# - DB: 5432 from app SG

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Public Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb"
    Tier = "public"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet (reserved for future ACM listener)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all egress (targets are constrained by app SG ingress)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app"
  description = "Application workloads (ECS instances / tasks)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-app"
    Tier = "private"
  })
}

# Public path: ALB may only reach the frontend host port.
resource "aws_vpc_security_group_ingress_rule" "app_frontend_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Frontend from ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.ecs_frontend_host_port
  to_port                      = var.ecs_frontend_host_port
  referenced_security_group_id = aws_security_group.alb.id
}

# Private path: backend stays off the ALB; allow VPC peers in the app SG (e.g. frontend→API).
resource "aws_vpc_security_group_ingress_rule" "app_backend_from_app" {
  security_group_id            = aws_security_group.app.id
  description                  = "Backend from app tier (VPC-local only)"
  ip_protocol                  = "tcp"
  from_port                    = var.ecs_backend_host_port
  to_port                      = var.ecs_backend_host_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all egress (image pulls, RDS, AWS APIs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db"
  description = "RDS PostgreSQL (app tier only)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-db"
    Tier = "data"
  })
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from app tier"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

# No broad egress on the DB SG — RDS does not need internet access.

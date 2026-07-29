# Security group baselines for future ALB → app → DB traffic.
# Rules stay minimal; tighten further when EKS/RDS are introduced.
#
# Cost: security groups are free.
# Naming: AWS `name` and Name tag use the same value ({name_prefix}-{role}).

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Baseline for public Application Load Balancer"
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
  description       = "HTTPS from internet"
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
  description = "Baseline for private application workloads (EKS nodes / pods)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-app"
    Tier = "private"
  })
}

# Allow ALB health checks and HTTP traffic into the app tier.
# Port range is broad for EKS/node-port flexibility; narrow when services are fixed.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 1
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all egress (image pulls, RDS, AWS APIs via NAT)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db"
  description = "Baseline for RDS PostgreSQL (app tier only)"
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

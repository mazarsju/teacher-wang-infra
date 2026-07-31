# Application Load Balancer — ingress to the frontend only.
#
# Cost notes:
# - ALB ~$16/mo + LCU charges whenever enable_ecs is true (destroyed with ECS).
# - No access logs / WAF yet (extra cost).
# - With CloudFront: public HTTPS is on CloudFront; ALB :80 is the CF origin.
# - ACM (regional) still used for the ALB :443 listener (optional direct access).
#
# Security model:
# - Internet → CloudFront → ALB :80 → frontend target group (host port).
# - Backend is NOT registered on the ALB (VPC / same-host only).
# - Without CloudFront + domain: :80 redirects to HTTPS on the ALB.

resource "aws_lb" "app" {
  count = var.enable_ecs ? 1 : 0

  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb"
    Tier = "public"
  })
}

resource "aws_lb_target_group" "frontend" {
  count = var.enable_ecs ? 1 : 0

  name        = "${local.name_prefix}-frontend"
  port        = var.ecs_frontend_host_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.alb_frontend_health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-frontend"
    Tier = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  count = var.enable_ecs ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = 80
  protocol          = "HTTP"

  # CloudFront terminates viewer TLS and fetches the origin over HTTP.
  # Only redirect :80→:443 when the ALB itself is the public HTTPS edge.
  dynamic "default_action" {
    for_each = local.alb_https_enabled && !local.cloudfront_enabled ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.alb_https_enabled && !local.cloudfront_enabled ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.frontend[0].arn
    }
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-http"
    Tier = "public"
  })
}

resource "aws_lb_listener" "https" {
  count = local.alb_https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-https"
    Tier = "public"
  })
}

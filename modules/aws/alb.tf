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
# - When CloudFront is on, listeners require header X-Origin-Verify (shared secret).
# - Without CloudFront + domain: :80 redirects to HTTPS on the ALB.

resource "random_password" "cloudfront_origin_verify" {
  count = local.cloudfront_enabled ? 1 : 0

  length  = 32
  special = false
}

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

  # Behind CloudFront: reject requests that omit the shared origin secret.
  dynamic "default_action" {
    for_each = local.cloudfront_enabled ? [1] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "Forbidden"
        status_code  = "403"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.alb_https_enabled || local.cloudfront_enabled ? [] : [1]
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

resource "aws_lb_listener_rule" "http_cloudfront_origin" {
  count = local.cloudfront_enabled ? 1 : 0

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.cloudfront_origin_verify[0].result]
    }
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-http-cf-origin"
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

  dynamic "default_action" {
    for_each = local.cloudfront_enabled ? [1] : []
    content {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "Forbidden"
        status_code  = "403"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.cloudfront_enabled ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.frontend[0].arn
    }
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-https"
    Tier = "public"
  })
}

resource "aws_lb_listener_rule" "https_cloudfront_origin" {
  count = local.cloudfront_enabled ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.cloudfront_origin_verify[0].result]
    }
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-https-cf-origin"
    Tier = "public"
  })
}

# Public DNS (Route 53) + ACM for the ALB hostname.
#
# Cost notes:
# - Hosted zone ~$0.50/mo + tiny query charges when alb_domain_name is set.
# - ACM public certificates are free.
# - Zone/cert stay even if enable_ecs is false (avoids NS churn); HTTPS listener
#   and apex alias appear only when the ALB exists (alb_https_enabled).
#
# After first apply that creates the zone: in Namecheap set Custom DNS nameservers
# to route53_name_servers. Certificate validation waits until NS delegate correctly.

resource "aws_route53_zone" "app" {
  count = local.alb_domain_configured ? 1 : 0

  name = var.alb_domain_name

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-dns"
    Tier = "public"
  })
}

resource "aws_acm_certificate" "alb" {
  count = local.alb_domain_configured ? 1 : 0

  domain_name       = var.alb_domain_name
  validation_method = "DNS"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-alb-cert"
    Tier = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.alb_domain_configured ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.app[0].zone_id
}

resource "aws_acm_certificate_validation" "alb" {
  # Only block apply when the ALB needs an ISSUED cert (ECS on + domain).
  # Zone + validation CNAMEs can exist earlier so you can set registrar NS first.
  count = local.alb_https_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}

resource "aws_route53_record" "alb_alias" {
  count = local.alb_https_enabled ? 1 : 0

  zone_id = aws_route53_zone.app[0].zone_id
  name    = var.alb_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app[0].dns_name
    zone_id                = aws_lb.app[0].zone_id
    evaluate_target_health = true
  }
}

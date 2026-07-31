# CloudFront in front of the ALB + S3 maintenance page for origin 5xx.
#
# Cost: typically ~$0 under CloudFront Free / always-free allowances for hobby traffic.
# ACM for CloudFront must live in us-east-1 (provider alias aws.us_east_1).
#
# Path: browser → CloudFront (HTTPS) → ALB :80 → ECS frontend.
# CloudFront adds X-Origin-Verify; ALB listener rules require it (blocks ALB DNS bypass).
# When the ALB returns 502/503/504 (e.g. single-host ECS deploy gap), CloudFront
# serves /maintenance.html from a private S3 bucket (OAC).

locals {
  cloudfront_alb_origin_id = "${local.name_prefix}-alb"
  cloudfront_s3_origin_id  = "${local.name_prefix}-maintenance-s3"

  # AWS managed cache / origin-request policies (stable IDs).
  cloudfront_cache_disabled    = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cloudfront_cache_optimized   = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cloudfront_origin_all_viewer = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

# --- Maintenance static assets (private; CloudFront OAC only) -----------------

resource "aws_s3_bucket" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket = "${local.name_prefix}-maintenance-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-maintenance"
    Tier = "public"
  })
}

resource "aws_s3_bucket_public_access_block" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.maintenance[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.maintenance[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.maintenance[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_object" "maintenance_html" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket       = aws_s3_bucket.maintenance[0].id
  key          = "maintenance.html"
  source       = "${path.module}/static/maintenance/maintenance.html"
  etag         = filemd5("${path.module}/static/maintenance/maintenance.html")
  content_type = "text/html; charset=utf-8"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-maintenance-html"
    Tier = "public"
  })
}

resource "aws_cloudfront_origin_access_control" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  name                              = "${local.name_prefix}-maintenance-oac"
  description                       = "OAC for Teacher Wang maintenance page"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "maintenance_bucket" {
  count = local.cloudfront_enabled ? 1 : 0

  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.app[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "maintenance" {
  count = local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.maintenance[0].id
  policy = data.aws_iam_policy_document.maintenance_bucket[0].json
}

# --- ACM in us-east-1 (required by CloudFront) --------------------------------

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1
  count    = local.cloudfront_enabled ? 1 : 0

  domain_name       = var.alb_domain_name
  validation_method = "DNS"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cloudfront-cert"
    Tier = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1
  count    = local.cloudfront_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "45m"
  }
}

# --- Distribution -------------------------------------------------------------

resource "aws_cloudfront_distribution" "app" {
  count = local.cloudfront_enabled ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} public site"
  aliases             = [var.alb_domain_name]
  price_class         = "PriceClass_100"
  wait_for_deployment = true

  origin {
    domain_name = aws_lb.app[0].dns_name
    origin_id   = local.cloudfront_alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.cloudfront_origin_verify[0].result
    }
  }

  origin {
    domain_name              = aws_s3_bucket.maintenance[0].bucket_regional_domain_name
    origin_id                = local.cloudfront_s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.maintenance[0].id
  }

  # Maintenance HTML from S3 (also the custom error response target).
  ordered_cache_behavior {
    path_pattern           = "/maintenance.html"
    target_origin_id       = local.cloudfront_s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = local.cloudfront_cache_optimized
  }

  default_cache_behavior {
    target_origin_id         = local.cloudfront_alb_origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = local.cloudfront_cache_disabled
    origin_request_policy_id = local.cloudfront_origin_all_viewer
  }

  # Deploy gap / no healthy targets → friendly page instead of raw ALB 503 HTML.
  dynamic "custom_error_response" {
    for_each = toset([502, 503, 504])
    content {
      error_code            = custom_error_response.value
      response_code         = 503
      response_page_path    = "/maintenance.html"
      error_caching_min_ttl = 30
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cdn"
    Tier = "public"
  })

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.http_cloudfront_origin,
    aws_s3_object.maintenance_html,
  ]
}

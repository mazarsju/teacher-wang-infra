# Naming and tagging conventions.
# All resource Name tags and AWS name attributes should use local.name_prefix.

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Merged onto resources that accept tags (default_tags still apply from the root provider).
  resource_tags = var.additional_tags

  alb_domain_configured = var.alb_domain_name != null && var.alb_domain_name != ""
  # HTTPS listener + apex alias require both a domain and a live ALB (ECS on).
  alb_https_enabled = var.enable_ecs && local.alb_domain_configured
  # Public DNS → CloudFront → ALB; S3 holds the deploy maintenance page.
  cloudfront_enabled = local.alb_https_enabled
}

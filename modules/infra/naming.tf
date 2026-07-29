# Naming and tagging conventions.
# All resource Name tags and AWS name attributes should use local.name_prefix.

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Merged onto resources that accept tags (default_tags still apply from the root provider).
  resource_tags = var.additional_tags
}

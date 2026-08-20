# Guardian API key for the backend ECS task.
#
# Seed via TF_VAR_guardian_api_key (preferred for first apply), or point at an
# existing secret with guardian_api_key_secret_arn. Plain string secret (not JSON).
# ~$0.40/mo while the secret exists.

locals {
  guardian_api_key_from_vars = (
    var.guardian_api_key != null &&
    var.guardian_api_key != ""
  )

  guardian_api_key_from_secret_arn = (
    var.guardian_api_key_secret_arn != null &&
    var.guardian_api_key_secret_arn != ""
  )

  guardian_api_key_secret_arn = local.guardian_api_key_from_vars ? (
    aws_secretsmanager_secret.guardian_api_key[0].arn
    ) : (
    local.guardian_api_key_from_secret_arn ? var.guardian_api_key_secret_arn : null
  )
}

resource "aws_secretsmanager_secret" "guardian_api_key" {
  count = local.guardian_api_key_from_vars ? 1 : 0

  name                    = "${local.name_prefix}-guardian-api-key"
  description             = "Guardian API key for the backend (plain string)"
  recovery_window_in_days = 0

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-guardian-api-key"
    Tier = "shared"
  })
}

resource "aws_secretsmanager_secret_version" "guardian_api_key" {
  count = local.guardian_api_key_from_vars ? 1 : 0

  secret_id     = aws_secretsmanager_secret.guardian_api_key[0].id
  secret_string = var.guardian_api_key
}

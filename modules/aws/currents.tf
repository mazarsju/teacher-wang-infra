# Currents.dev API key for the backend ECS task.
#
# Seed via TF_VAR_currents_api_key (preferred for first apply), or point at an
# existing secret with currents_api_key_secret_arn. Plain string secret (not JSON).
# ~$0.40/mo while the secret exists.

locals {
  currents_api_key_from_vars = (
    var.currents_api_key != null &&
    var.currents_api_key != ""
  )

  currents_api_key_from_secret_arn = (
    var.currents_api_key_secret_arn != null &&
    var.currents_api_key_secret_arn != ""
  )

  currents_api_key_secret_arn = local.currents_api_key_from_vars ? (
    aws_secretsmanager_secret.currents_api_key[0].arn
    ) : (
    local.currents_api_key_from_secret_arn ? var.currents_api_key_secret_arn : null
  )
}

resource "aws_secretsmanager_secret" "currents_api_key" {
  count = local.currents_api_key_from_vars ? 1 : 0

  name                    = "${local.name_prefix}-currents-api-key"
  description             = "Currents API key for the backend (plain string)"
  recovery_window_in_days = 0

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-currents-api-key"
    Tier = "shared"
  })
}

resource "aws_secretsmanager_secret_version" "currents_api_key" {
  count = local.currents_api_key_from_vars ? 1 : 0

  secret_id     = aws_secretsmanager_secret.currents_api_key[0].id
  secret_string = var.currents_api_key
}

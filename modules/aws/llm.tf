# LLM provider credentials for the backend ECS task.
#
# Seed via TF_VAR_llm_api_key (preferred for first apply), or point at an
# existing secret with llm_api_key_secret_arn. Plain string secret (not JSON).
# ~$0.40/mo while the secret exists.

locals {
  llm_api_key_from_vars = (
    var.llm_api_key != null &&
    var.llm_api_key != ""
  )

  llm_api_key_from_secret_arn = (
    var.llm_api_key_secret_arn != null &&
    var.llm_api_key_secret_arn != ""
  )

  llm_api_key_secret_arn = local.llm_api_key_from_vars ? (
    aws_secretsmanager_secret.llm_api_key[0].arn
    ) : (
    local.llm_api_key_from_secret_arn ? var.llm_api_key_secret_arn : null
  )
}

resource "aws_secretsmanager_secret" "llm_api_key" {
  count = local.llm_api_key_from_vars ? 1 : 0

  name                    = "${local.name_prefix}-llm-api-key"
  description             = "LLM provider API key for the backend (plain string)"
  recovery_window_in_days = 0

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-llm-api-key"
    Tier = "shared"
  })
}

resource "aws_secretsmanager_secret_version" "llm_api_key" {
  count = local.llm_api_key_from_vars ? 1 : 0

  secret_id     = aws_secretsmanager_secret.llm_api_key[0].id
  secret_string = var.llm_api_key
}

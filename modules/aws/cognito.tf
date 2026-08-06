# Amazon Cognito User Pool — end-user credentials (password + Google SSO).
#
# Cost: ~$0 under Cognito free-tier MAU (Lite/Essentials). No always-on compute.
# Google IdP is created when either:
#   - TF_VAR_cognito_google_client_id + TF_VAR_cognito_google_client_secret are set, or
#   - cognito_google_oauth_secret_arn points at a Secrets Manager secret
#     with JSON {"client_id":"...","client_secret":"..."}
# Redirect URI to register in Google Cloud Console (also terraform output):
#   ${cognito_hosted_ui_base_url}/oauth2/idpresponse

locals {
  cognito_google_from_vars = (
    var.cognito_google_client_id != null &&
    var.cognito_google_client_id != "" &&
    var.cognito_google_client_secret != null &&
    var.cognito_google_client_secret != ""
  )

  cognito_google_from_secret_arn = (
    var.cognito_google_oauth_secret_arn != null &&
    var.cognito_google_oauth_secret_arn != ""
  )

  cognito_google_enabled = local.cognito_google_from_vars || local.cognito_google_from_secret_arn

  cognito_google_creds = local.cognito_google_from_vars ? {
    client_id     = var.cognito_google_client_id
    client_secret = var.cognito_google_client_secret
    } : local.cognito_google_from_secret_arn ? {
    client_id     = jsondecode(data.aws_secretsmanager_secret_version.cognito_google[0].secret_string)["client_id"]
    client_secret = jsondecode(data.aws_secretsmanager_secret_version.cognito_google[0].secret_string)["client_secret"]
  } : null

  cognito_identity_providers = concat(
    ["COGNITO"],
    local.cognito_google_enabled ? ["Google"] : [],
  )

  # Prefix must be unique per region; include account id to avoid collisions.
  cognito_domain_prefix = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"

  cognito_hosted_ui_base_url = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"

  cognito_google_redirect_uri = "${local.cognito_hosted_ui_base_url}/oauth2/idpresponse"

  cognito_callback_urls = distinct(concat(
    var.cognito_callback_urls,
    local.alb_domain_configured ? [
      "https://${var.alb_domain_name}/",
      "https://${var.alb_domain_name}/login",
    ] : [],
  ))

  cognito_logout_urls = distinct(concat(
    var.cognito_logout_urls,
    local.alb_domain_configured ? [
      "https://${var.alb_domain_name}/",
      "https://${var.alb_domain_name}/login",
    ] : [],
  ))

  cognito_issuer = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-users"

  # Sign-in with chosen username; email is a required attribute (not an alias —
  # Cognito forbids required + alias on the same attribute).
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Unique email + Google→existing-user linking (see cognito_pre_signup.tf).
  lambda_config {
    pre_sign_up = aws_lambda_function.cognito_pre_signup.arn
  }

  # Default Cognito email (no SES charge). Switch to SES later if volume needs it.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-users"
    Tier = "shared"
  })
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = local.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# Persist Google OAuth client credentials when provided via TF_VAR (ops / rotation).
# ~$0.40/mo only while Google SSO is enabled this way.
resource "aws_secretsmanager_secret" "cognito_google" {
  count = local.cognito_google_from_vars ? 1 : 0

  name                    = "${local.name_prefix}-cognito-google"
  description             = "Google OAuth Web client for Cognito IdP (JSON client_id + client_secret)"
  recovery_window_in_days = 0

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cognito-google"
    Tier = "shared"
  })
}

resource "aws_secretsmanager_secret_version" "cognito_google" {
  count = local.cognito_google_from_vars ? 1 : 0

  secret_id = aws_secretsmanager_secret.cognito_google[0].id
  secret_string = jsonencode({
    client_id     = var.cognito_google_client_id
    client_secret = var.cognito_google_client_secret
  })
}

data "aws_secretsmanager_secret_version" "cognito_google" {
  count = local.cognito_google_from_secret_arn && !local.cognito_google_from_vars ? 1 : 0

  secret_id = var.cognito_google_oauth_secret_arn
}

resource "aws_cognito_identity_provider" "google" {
  count = local.cognito_google_enabled ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id                     = local.cognito_google_creds.client_id
    client_secret                 = local.cognito_google_creds.client_secret
    authorize_scopes              = "openid email profile"
    attributes_url_add_attributes = "true"
  }

  attribute_mapping = {
    email       = "email"
    username    = "sub"
    name        = "name"
    given_name  = "given_name"
    family_name = "family_name"
    picture     = "picture"
  }

  # Cognito fills authorize_url / token_url / etc. after create; ignore to avoid perpetual diffs.
  lifecycle {
    ignore_changes = [
      provider_details["attributes_url"],
      provider_details["authorize_url"],
      provider_details["token_url"],
      provider_details["oidc_issuer"],
      provider_details["jwks_uri"],
      provider_details["attributes_request_method"],
    ]
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${local.name_prefix}-app"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  supported_identity_providers = local.cognito_identity_providers

  callback_urls = local.cognito_callback_urls
  logout_urls   = local.cognito_logout_urls

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  access_token_validity  = 2
  id_token_validity      = 2
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # App client must be created/updated after the Google IdP exists when enabled.
  depends_on = [aws_cognito_identity_provider.google]
}

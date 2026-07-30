# Amazon Cognito User Pool — end-user credentials (password + optional Google SSO).
#
# Cost: ~$0 under Cognito free-tier MAU (Lite/Essentials). No always-on compute.
# Google IdP is created only when both client id and secret are set.

locals {
  cognito_google_enabled = (
    var.cognito_google_client_id != null &&
    var.cognito_google_client_id != "" &&
    var.cognito_google_client_secret != null &&
    var.cognito_google_client_secret != ""
  )

  cognito_identity_providers = concat(
    ["COGNITO"],
    local.cognito_google_enabled ? ["Google"] : [],
  )

  # Prefix must be unique per region; include account id to avoid collisions.
  cognito_domain_prefix = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"

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

resource "aws_cognito_identity_provider" "google" {
  count = local.cognito_google_enabled ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id                     = var.cognito_google_client_id
    client_secret                 = var.cognito_google_client_secret
    authorize_scopes              = "openid email profile"
    attributes_url_add_attributes = "true"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
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

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # App client must be created/updated after the Google IdP exists when enabled.
  depends_on = [aws_cognito_identity_provider.google]
}

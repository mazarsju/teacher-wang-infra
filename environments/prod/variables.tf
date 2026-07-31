variable "cognito_google_client_id" {
  description = "Google OAuth Web client ID for Cognito. Leave null for password-only. Prefer TF_VAR_cognito_google_client_id."
  type        = string
  default     = null
}

variable "cognito_google_client_secret" {
  description = "Google OAuth Web client secret for Cognito. Leave null for password-only. Prefer TF_VAR_cognito_google_client_secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "cognito_google_oauth_secret_arn" {
  description = "Optional Secrets Manager secret ARN with JSON client_id/client_secret (alternative to TF_VAR pair)."
  type        = string
  default     = null
}

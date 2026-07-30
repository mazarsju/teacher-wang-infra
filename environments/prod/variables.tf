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

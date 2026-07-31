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

variable "llm_api_key" {
  description = "LLM provider API key for the backend. Prefer TF_VAR_llm_api_key; stored in Secrets Manager."
  type        = string
  default     = null
  sensitive   = true
}

variable "llm_api_key_secret_arn" {
  description = "Optional Secrets Manager ARN for a plain-string LLM API key (alternative to TF_VAR_llm_api_key)."
  type        = string
  default     = null
}

variable "llm_model" {
  description = "LLM model id for the backend (LLM_MODEL env). Override with TF_VAR_llm_model if needed."
  type        = string
  default     = "gpt-4o-mini"
}

variable "gcp_project_id" {
  description = "GCP project ID for Google SSO OAuth client (Console)"
  type        = string
  default     = "teacher-wang"
}

variable "gcp_billing_account" {
  description = "GCP billing account ID (XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  default     = "01FAA2-0A2C47-146756"
}

variable "gcp_support_email" {
  description = "OAuth consent screen support email"
  type        = string
  default     = "mazarsju@gmail.com"
}

variable "gcp_create_project" {
  description = "Create the GCP project with Terraform. Use false when the project already exists (avoids 409 alreadyExists)."
  type        = bool
  default     = false
}

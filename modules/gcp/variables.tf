variable "project_id" {
  description = "GCP project ID (globally unique)"
  type        = string
}

variable "project_name" {
  description = "Human-readable GCP project name"
  type        = string
  default     = "Teacher Wang"
}

variable "billing_account" {
  description = "GCP billing account ID (format XXXXXX-XXXXXX-XXXXXX), no billingAccounts/ prefix"
  type        = string
}

variable "support_email" {
  description = "Support email for the Google OAuth consent screen (must manage the project)"
  type        = string
}

variable "application_title" {
  description = "OAuth consent screen application title"
  type        = string
  default     = "Teacher Wang"
}

variable "cognito_google_redirect_uri" {
  description = "Cognito IdP callback URI to register on the Google OAuth Web client"
  type        = string
}

variable "authorized_javascript_origins" {
  description = "Origins to register on the Google OAuth Web client (SPA)"
  type        = list(string)
  default = [
    "https://teacherwang.xyz",
    "http://localhost:5173",
  ]
}

variable "create_project" {
  description = "When true, create the GCP project. When false, expect an existing project (import or pre-created)."
  type        = bool
  default     = true
}

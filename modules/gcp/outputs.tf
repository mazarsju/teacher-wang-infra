output "project_id" {
  description = "GCP project ID"
  value       = local.project_id
}

output "project_number" {
  description = "GCP project number"
  value       = var.create_project ? google_project.main[0].number : data.google_project.existing[0].number
}

output "billing_account" {
  description = "Billing account linked to the project"
  value       = var.billing_account
}

output "oauth_support_email" {
  description = "Support email for the OAuth consent screen"
  value       = var.support_email
}

output "oauth_application_title" {
  description = "OAuth consent screen application title"
  value       = var.application_title
}

output "cognito_google_redirect_uri" {
  description = "Authorized redirect URI for the Google OAuth Web client (Cognito)"
  value       = var.cognito_google_redirect_uri
}

output "authorized_javascript_origins" {
  description = "Authorized JavaScript origins for the Google OAuth Web client"
  value       = var.authorized_javascript_origins
}

output "oauth_console_url" {
  description = "Google Cloud Console credentials page for this project"
  value       = "https://console.cloud.google.com/apis/credentials?project=${local.project_id}"
}

output "oauth_setup_checklist" {
  description = "One-time Console steps to create the OAuth Web client (not automatable via Terraform)"
  value       = <<-EOT
    1. Open https://console.cloud.google.com/apis/credentials?project=${local.project_id}
       (account: ${var.support_email})
    2. Configure OAuth consent screen if prompted:
       - User type: External
       - App name: ${var.application_title}
       - Support email / developer contact: ${var.support_email}
       - Scopes: openid, email, profile (defaults are fine)
       - Add yourself as a test user while in Testing
    3. Create credentials → OAuth client ID → Application type: Web application
       Name: teacher-wang-cognito
    4. Authorized JavaScript origins:
${join("\n", [for o in var.authorized_javascript_origins : "       - ${o}"])}
    5. Authorized redirect URIs (exact):
       - ${var.cognito_google_redirect_uri}
    6. Copy Client ID + Client secret into infra config:
         export TF_VAR_cognito_google_client_id="..."
         export TF_VAR_cognito_google_client_secret="..."
       then: cd environments/prod && terraform apply
       Expect: cognito_google_enabled = true
  EOT
}

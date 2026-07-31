# GCP project scaffolding for Google SSO (Cognito federation).
#
# Cost: GCP project + OAuth Web client are free for Sign in with Google.
# Note: Google no longer exposes a stable public API to create classic OAuth 2.0
# Web clients via Terraform (IAP OAuth Admin API deprecated). This module:
#   1) creates/links the project + billing
#   2) enables required APIs
#   3) outputs an exact Console checklist (redirect URI = Cognito callback)
# After you create the Web client once, wire client_id/secret into AWS Cognito
# via TF_VAR_cognito_google_client_* (see root README).

locals {
  project_id = var.create_project ? google_project.main[0].project_id : data.google_project.existing[0].project_id

  # APIs useful for project management + Google identity attribute lookups.
  enabled_services = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "cloudbilling.googleapis.com",
    "people.googleapis.com",
  ])
}

resource "google_project" "main" {
  count = var.create_project ? 1 : 0

  name            = var.project_name
  project_id      = var.project_id
  billing_account = var.billing_account

  # Personal Google accounts typically have no org; omit org_id / folder_id.
  labels = {
    app         = "teacher-wang"
    managed_by  = "terraform"
    environment = "prod"
  }
}

data "google_project" "existing" {
  count = var.create_project ? 0 : 1

  project_id = var.project_id
}

resource "google_billing_project_info" "main" {
  count = var.create_project ? 0 : 1

  project         = data.google_project.existing[0].project_id
  billing_account = var.billing_account
}

resource "google_project_service" "apis" {
  for_each = local.enabled_services

  project            = local.project_id
  service            = each.value
  disable_on_destroy = false
}

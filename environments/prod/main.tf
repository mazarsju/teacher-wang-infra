locals {
  environment = "prod"

  # Prod-specific overrides (shared defaults come from module.common).
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false
  # ECS control plane is free; cost is the EC2 Spot instance. Keep false when idle.
  enable_ecs = true
  # Public site hostname (Route 53 + ACM). Domain registered at Namecheap; set
  # Namecheap Custom DNS to terraform output route53_name_servers. HTTPS when enable_ecs is true.
  alb_domain_name = "teacherwang.xyz"
}

module "common" {
  source = "../common"
}

module "infra" {
  source = "../../modules/infra"

  project_name       = module.common.project_name
  aws_region         = module.common.aws_region
  az_count           = module.common.az_count
  environment        = local.environment
  vpc_cidr           = local.vpc_cidr
  enable_nat_gateway = local.enable_nat_gateway
  enable_ecs         = local.enable_ecs
  alb_domain_name    = local.alb_domain_name

  # Google SSO. Set via TF_VAR_cognito_google_client_id / _secret after creating
  # the OAuth Web client in GCP (see module.gcp oauth_setup_checklist output).
  cognito_google_client_id        = var.cognito_google_client_id
  cognito_google_client_secret    = var.cognito_google_client_secret
  cognito_google_oauth_secret_arn = var.cognito_google_oauth_secret_arn
}

# GCP project already exists (teacher-wang). Terraform manages billing link + APIs only.
# Set gcp_create_project=true only when creating a brand-new project id.
module "gcp" {
  source = "../../modules/gcp"

  project_id                  = var.gcp_project_id
  project_name                = "Teacher Wang"
  billing_account             = var.gcp_billing_account
  support_email               = var.gcp_support_email
  application_title           = "Teacher Wang"
  create_project              = var.gcp_create_project
  cognito_google_redirect_uri = module.infra.cognito_google_redirect_uri
  authorized_javascript_origins = [
    "https://${local.alb_domain_name}",
    "http://localhost:5173",
  ]
}

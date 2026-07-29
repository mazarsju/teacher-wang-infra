locals {
  environment = "prod"

  # Prod-specific overrides (shared defaults come from module.common).
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false
  # ECS control plane is free; cost is the EC2 Spot instance. Keep false when idle.
  enable_ecs = false
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
}

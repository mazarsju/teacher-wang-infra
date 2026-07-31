# ECR repositories for backend and frontend container images.
#
# Cost notes:
# - Storage billed per GB-month; lifecycle rules expire old/untagged images.
# - AES256 encryption (no CMK charge). Basic scan-on-push is free.
# - No VPC interface endpoints yet — local/CI pushes use the public ECR endpoint.

locals {
  ecr_repositories = {
    backend  = "${local.name_prefix}-backend"
    frontend = "${local.name_prefix}-frontend"
  }
}

resource "aws_ecr_repository" "app" {
  for_each = local.ecr_repositories

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.resource_tags, {
    Name = each.value
    Tier = "shared"
  })
}

# Cap registry storage: drop untagged digests quickly; keep a short tagged history.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

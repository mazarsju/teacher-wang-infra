provider "aws" {
  region = var.aws_region

  # Credentials are resolved from the environment (preferred for now):
  #   source ../config   # sets AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
  # or from AWS_PROFILE / the default AWS shared credentials file.
  #
  # Do not hard-code secrets in Terraform files.
  default_tags {
    tags = {
      Project     = "teacher-wang"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

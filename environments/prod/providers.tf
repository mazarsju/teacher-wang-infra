# Provider config is evaluated before modules, so shared values are inlined here.
# Keep in sync with environments/common outputs.
provider "aws" {
  region = "eu-west-1"

  # Credentials are resolved from the environment (preferred for now):
  #   source ../../../config   # from environments/prod
  # or from AWS_PROFILE / the default AWS shared credentials file.
  #
  # Do not hard-code secrets in Terraform files.
  default_tags {
    tags = {
      Project     = "teacher-wang"
      ManagedBy   = "terraform"
      Environment = "prod"
    }
  }
}

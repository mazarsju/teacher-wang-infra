terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend (S3 + DynamoDB) will be added once the account
  # bootstrap and networking foundations are in place.
}

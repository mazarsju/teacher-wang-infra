# Bootstrap / connectivity check.
# This data source confirms Terraform can authenticate against AWS.
# Real infrastructure modules (VPC, EKS, RDS, etc.) will replace this later.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

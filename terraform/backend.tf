# S3 remote state with native S3 locking (no DynamoDB).
# Requires Terraform >= 1.10 (`use_lockfile`).
#
# Account-specific values live in backend.hcl (gitignored):
#   cp backend.hcl.example backend.hcl
#   # set bucket to teacher-wang-tfstate-<aws_account_id>
#
# First-time bootstrap (chicken-and-egg):
#   1. Temporarily move this file aside (or use local state)
#   2. terraform init && terraform apply   # creates the state bucket
#   3. Write backend.hcl with the bucket name from terraform output
#   4. Restore this file, then:
#        terraform init -backend-config=backend.hcl -migrate-state -force-copy
terraform {
  backend "s3" {
    key          = "teacher-wang/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

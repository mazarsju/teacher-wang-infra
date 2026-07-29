output "aws_account_id" {
  description = "AWS account ID used by the current credentials"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "ARN of the IAM principal Terraform is authenticated as"
  value       = data.aws_caller_identity.current.arn
}

output "aws_region" {
  description = "Effective AWS region"
  value       = data.aws_region.current.name
}

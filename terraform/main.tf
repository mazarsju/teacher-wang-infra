# Account / region context used by naming and default tags.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Pre Sign-up Lambda: enforce unique email + link Google SSO to existing users.
#
# Cost: Lambda free-tier friendly; short CloudWatch log retention (7 days).

data "archive_file" "cognito_pre_signup" {
  type        = "zip"
  source_file = "${path.module}/lambda/cognito_pre_signup/index.py"
  output_path = "${path.module}/lambda/cognito_pre_signup.zip"
}

resource "aws_cloudwatch_log_group" "cognito_pre_signup" {
  name              = "/aws/lambda/${local.name_prefix}-cognito-pre-signup"
  retention_in_days = 7

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cognito-pre-signup-logs"
    Tier = "shared"
  })
}

data "aws_iam_policy_document" "cognito_pre_signup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cognito_pre_signup" {
  name               = "${local.name_prefix}-cognito-pre-signup"
  assume_role_policy = data.aws_iam_policy_document.cognito_pre_signup_assume.json

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cognito-pre-signup"
    Tier = "shared"
  })
}

data "aws_iam_policy_document" "cognito_pre_signup" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.cognito_pre_signup.arn}:*"]
  }

  statement {
    # Scoped to this account/region (not the pool resource itself) so Terraform
    # can create the Lambda before / with the user pool without a dependency cycle.
    sid = "CognitoLinkByEmail"
    actions = [
      "cognito-idp:ListUsers",
      "cognito-idp:AdminLinkProviderForUser",
    ]
    resources = [
      "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/*",
    ]
  }
}

resource "aws_iam_role_policy" "cognito_pre_signup" {
  name   = "${local.name_prefix}-cognito-pre-signup"
  role   = aws_iam_role.cognito_pre_signup.id
  policy = data.aws_iam_policy_document.cognito_pre_signup.json
}

resource "aws_lambda_function" "cognito_pre_signup" {
  function_name = "${local.name_prefix}-cognito-pre-signup"
  description   = "Cognito Pre Sign-up: unique email + link Google IdP to existing users"
  role          = aws_iam_role.cognito_pre_signup.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.cognito_pre_signup.output_path
  source_code_hash = data.archive_file.cognito_pre_signup.output_base64sha256

  depends_on = [
    aws_cloudwatch_log_group.cognito_pre_signup,
    aws_iam_role_policy.cognito_pre_signup,
  ]

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-cognito-pre-signup"
    Tier = "shared"
  })
}

resource "aws_lambda_permission" "cognito_pre_signup" {
  statement_id  = "AllowCognitoPreSignUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_pre_signup.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

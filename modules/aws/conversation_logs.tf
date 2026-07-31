# Private S3 bucket for per-user chat transcripts (backend ECS task role reads/writes).

resource "aws_s3_bucket" "conversation_logs" {
  bucket = "${local.name_prefix}-conversation-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-conversation-logs"
    Tier = "private"
  })
}

resource "aws_s3_bucket_public_access_block" "conversation_logs" {
  bucket = aws_s3_bucket.conversation_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "conversation_logs" {
  bucket = aws_s3_bucket.conversation_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "conversation_logs" {
  bucket = aws_s3_bucket.conversation_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "ecs_task_conversation_logs" {
  count = var.enable_ecs ? 1 : 0

  statement {
    sid    = "ListUserConversationPrefixes"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.conversation_logs.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "users/",
        "users/*",
      ]
    }
  }

  statement {
    sid    = "ReadWriteDeleteUserConversationObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.conversation_logs.arn}/users/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_conversation_logs" {
  count = var.enable_ecs ? 1 : 0

  name   = "${local.name_prefix}-ecs-task-conversation-logs"
  role   = aws_iam_role.ecs_task[0].id
  policy = data.aws_iam_policy_document.ecs_task_conversation_logs[0].json
}

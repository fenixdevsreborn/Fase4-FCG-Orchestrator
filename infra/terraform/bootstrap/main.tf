data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition
  state_bucket  = coalesce(var.state_bucket_name, "${var.project_name}-${var.environment}-tfstate-${local.account_id}")
  role_name     = "${var.project_name}-${var.environment}-github-actions"
  policy_name   = "${var.project_name}-${var.environment}-github-actions"
  oidc_provider = "token.actions.githubusercontent.com"

  repo_subjects = [for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"]

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stack       = "bootstrap"
  })
}

# --------------------------------------------------------------------------------------------
# Remote state backend (S3 + DynamoDB lock) used by the main stack.
# --------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket        = local.state_bucket
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}

# --------------------------------------------------------------------------------------------
# GitHub Actions OIDC provider + IAM role assumed via aws-actions/configure-aws-credentials.
# --------------------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.oidc_provider}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = local.common_tags
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_provider}:sub"
      values   = local.repo_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.common_tags
}

# Permissions broad enough for Terraform apply of the main stack and ECR push from API CIs.
# Tighten by ARN once the platform is stable.
data "aws_iam_policy_document" "platform" {
  statement {
    sid    = "TerraformPlatform"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*",
      "iam:*",
      "rds:*",
      "elasticache:*",
      "es:*",
      "opensearch:*",
      "dynamodb:*",
      "secretsmanager:*",
      "logs:*",
      "kms:*",
      "ecr:*",
      "s3:*",
      "autoscaling:*",
      "cloudwatch:*",
      "elasticloadbalancing:*",
      "cloudformation:*",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TerraformStateBackend"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
  }

  statement {
    sid       = "TerraformStateLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
    resources = [aws_dynamodb_table.tfstate_lock.arn]
  }
}

resource "aws_iam_policy" "platform" {
  name   = local.policy_name
  policy = data.aws_iam_policy_document.platform.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "platform" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.platform.arn
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Role ARN to set as GitHub Actions secret AWS_GITHUB_ROLE_ARN."
}

output "tfstate_bucket" {
  value       = aws_s3_bucket.tfstate.bucket
  description = "S3 bucket holding the main stack remote state."
}

output "tfstate_lock_table" {
  value       = aws_dynamodb_table.tfstate_lock.name
  description = "DynamoDB table used for Terraform state locking."
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "GitHub Actions OIDC provider ARN."
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region used by the bootstrap stack."
}

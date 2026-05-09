output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint."
}

output "ecr_repository_urls" {
  value       = { for name, repository in aws_ecr_repository.repositories : name => repository.repository_url }
  description = "Private ECR repositories created for the platform."
}

output "catalog_irsa_role_arn" {
  value       = module.catalog_irsa_role.iam_role_arn
  description = "IRSA role ARN for the CatalogAPI service account."
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.catalog_metadata.name
  description = "DynamoDB table name used for catalog metadata."
}

output "opensearch_endpoint" {
  value       = aws_opensearch_domain.catalog.endpoint
  description = "OpenSearch endpoint for search traffic."
}

output "argocd_namespace" {
  value       = "argocd"
  description = "Namespace where Argo CD is installed."
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS account ID where the platform is deployed."
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region for the deployment."
}

output "ecr_registry" {
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  description = "ECR registry hostname for the account/region."
}

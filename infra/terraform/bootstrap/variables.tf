variable "aws_region" {
  type        = string
  description = "AWS region for the bootstrap resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project prefix for AWS resources."
  default     = "fcg"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "prod"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user that owns the repositories."
}

variable "github_repos" {
  type        = list(string)
  description = "Repository names allowed to assume the GitHub Actions role."
  default = [
    "Fase4-FCG-Orchestrator",
    "Fase4-FCG-UsersAPI",
    "Fase4-FCG-CatalogAPI",
    "Fase4-FCG-PaymentsAPI",
    "Fase4-FCG-NotificationsAPI"
  ]
}

variable "state_bucket_name" {
  type        = string
  description = "Override the Terraform state bucket name. Defaults to <project>-<env>-tfstate-<account-suffix>."
  default     = ""
}

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locking."
  default     = "fcg-prod-tfstate-lock"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply."
  default     = {}
}

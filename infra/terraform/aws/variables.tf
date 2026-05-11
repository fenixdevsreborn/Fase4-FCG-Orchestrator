variable "aws_region" {
  type        = string
  description = "AWS region for the deployment."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "prod"
}

variable "project_name" {
  type        = string
  description = "Project prefix for AWS resources."
  default     = "fcg"
}

variable "platform_namespace" {
  type        = string
  description = "Kubernetes namespace for the platform workloads."
  default     = "fcg-platform"
}

variable "cluster_version" {
  type        = string
  description = "EKS cluster version."
  default     = "1.34"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the private subnets."
}

variable "node_instance_types" {
  type        = list(string)
  description = "EKS managed node group instance types."
  default     = ["m7i-flex.large"]
}

variable "node_group_min_size" {
  type        = number
  description = "Minimum number of worker nodes."
  default     = 2
}

variable "node_group_desired_size" {
  type        = number
  description = "Desired number of worker nodes."
  default     = 2
}

variable "node_group_max_size" {
  type        = number
  description = "Maximum number of worker nodes."
  default     = 2
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t3.micro"
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type."
  default     = "cache.t3.micro"
}

variable "opensearch_instance_type" {
  type        = string
  description = "OpenSearch data node type."
  default     = "t3.small.search"
}

variable "mq_username" {
  type        = string
  description = "RabbitMQ admin username."
  default     = "fcg"
}

variable "opensearch_master_username" {
  type        = string
  description = "OpenSearch master username."
  default     = "fcgadmin"
}

variable "ecr_repositories" {
  type        = list(string)
  description = "Private ECR repositories to create."
  default = [
    "frontend-web",
    "gateway-api",
    "users-api",
    "catalog-api",
    "payments-api",
    "notifications-api"
  ]
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to AWS resources."
  default     = {}
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  postgres = {
    users = {
      db_name  = "users_db"
      username = "usersapi"
    }
    catalog = {
      db_name  = "catalogdb"
      username = "catalogapi"
    }
  }

  postgres_admin = {
    db_name  = "fcg_platform"
    username = "fcgadmin"
  }

  rabbitmq_host = replace(replace(aws_mq_broker.rabbitmq.instances[0].endpoints[0], "amqps://", ""), ":5671", "")

  secret_payloads = {
    "users-api" = {
      ConnectionStrings__DefaultConnection = "Host=${aws_db_instance.postgres.address};Port=${aws_db_instance.postgres.port};Database=${local.postgres.users.db_name};Username=${local.postgres.users.username};Password=${random_password.postgres["users"].result}"
      RabbitMQ__Host                       = local.rabbitmq_host
      RabbitMQ__Username                   = var.mq_username
      RabbitMQ__Password                   = random_password.rabbitmq.result
      Jwt__Key                             = random_password.users_jwt.result
    }
    "catalog-api" = {
      ConnectionStrings__CatalogDatabase = "Host=${aws_db_instance.postgres.address};Port=${aws_db_instance.postgres.port};Database=${local.postgres.catalog.db_name};Username=${local.postgres.catalog.username};Password=${random_password.postgres["catalog"].result}"
      RabbitMQ__Host                     = local.rabbitmq_host
      RabbitMQ__Username                 = var.mq_username
      RabbitMQ__Password                 = random_password.rabbitmq.result
      CatalogCache__ConnectionString     = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379,ssl=true,abortConnect=false"
      DynamoDb__TableName                = aws_dynamodb_table.catalog_metadata.name
      DynamoDb__Region                   = var.aws_region
      OpenSearch__Endpoint               = "https://${aws_opensearch_domain.catalog.endpoint}"
      OpenSearch__IndexName              = "fcg-games"
      OpenSearch__Username               = var.opensearch_master_username
      OpenSearch__Password               = random_password.opensearch.result
    }
    "payments-api" = {
      RabbitMQ__Host     = local.rabbitmq_host
      RabbitMQ__Username = var.mq_username
      RabbitMQ__Password = random_password.rabbitmq.result
    }
    "notifications-api" = {
      RABBITMQ_HOST     = local.rabbitmq_host
      RABBITMQ_USERNAME = var.mq_username
      RABBITMQ_PASSWORD = random_password.rabbitmq.result
    }
    "postgres-bootstrap" = {
      POSTGRES_HOST           = aws_db_instance.postgres.address
      POSTGRES_PORT           = tostring(aws_db_instance.postgres.port)
      POSTGRES_ADMIN_DATABASE = local.postgres_admin.db_name
      POSTGRES_ADMIN_USERNAME = local.postgres_admin.username
      POSTGRES_ADMIN_PASSWORD = random_password.postgres_admin.result
      USERS_DATABASE          = local.postgres.users.db_name
      USERS_USERNAME          = local.postgres.users.username
      USERS_PASSWORD          = random_password.postgres["users"].result
      CATALOG_DATABASE        = local.postgres.catalog.db_name
      CATALOG_USERNAME        = local.postgres.catalog.username
      CATALOG_PASSWORD        = random_password.postgres["catalog"].result
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway      = false
  single_nat_gateway      = false
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # Acesso ao cluster via console AWS e kubectl para o usuário fcg-bootstrap-admin
  access_entries = {
    console_admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/fcg-bootstrap-admin"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_group_min_size
      desired_size   = var.node_group_desired_size
      max_size       = var.node_group_max_size
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
    }
  }

  tags = local.common_tags
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.20.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  enable_external_secrets             = true
  enable_metrics_server               = true
  enable_argocd                       = true
  enable_aws_for_fluentbit            = false
  enable_aws_cloudwatch_metrics       = false

  argocd = {
    namespace = "argocd"
  }

  external_secrets = {
    namespace = "external-secrets"
  }

  aws_for_fluentbit = {
    enable_containerinsights = true
    set = [
      {
        name  = "cloudWatch.region"
        value = var.aws_region
      },
      {
        name  = "cloudWatch.logGroupName"
        value = "/aws/containerinsights/fcg-prod/application"
      }
    ]
  }

  tags = local.common_tags
}

resource "aws_security_group" "data_services" {
  name        = "${local.name}-data-services"
  description = "Security group shared by platform data services"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "random_password" "postgres" {
  for_each = local.postgres

  length  = 24
  special = false
}

resource "random_password" "postgres_admin" {
  length  = 24
  special = false
}

resource "random_password" "rabbitmq" {
  length  = 24
  special = false
}

resource "random_password" "opensearch" {
  length           = 16
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  override_special = "!#%&()-_=+[]{}?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 1
}

resource "random_password" "users_jwt" {
  length  = 48
  special = false
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name}-postgres"
  subnet_ids = module.vpc.private_subnets
  tags       = local.common_tags
}

resource "aws_db_instance" "postgres" {
  identifier             = "${local.name}-postgres"
  db_name                = local.postgres_admin.db_name
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_encrypted      = true
  username               = local.postgres_admin.username
  password               = random_password.postgres_admin.result
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.data_services.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  deletion_protection    = false
  multi_az               = false
  tags                   = local.common_tags
}

resource "aws_mq_broker" "rabbitmq" {
  broker_name                = "${local.name}-rabbitmq"
  deployment_mode            = "SINGLE_INSTANCE"
  engine_type                = "RabbitMQ"
  engine_version             = "3.13"
  host_instance_type         = var.mq_instance_type
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  subnet_ids                 = [module.vpc.private_subnets[0]]
  security_groups            = [aws_security_group.data_services.id]

  user {
    username = var.mq_username
    password = random_password.rabbitmq.result
  }

  logs {
    general = true
  }

  tags = local.common_tags
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = replace("${local.name}-redis", "_", "-")
  description                = "Redis cache for ${local.name}"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.redis_node_type
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.data_services.id]
  automatic_failover_enabled = false
  num_cache_clusters         = 1
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  parameter_group_name       = "default.redis7"
  tags                       = local.common_tags
}

resource "aws_opensearch_domain" "catalog" {
  domain_name    = replace("${local.name}-catalog", "_", "-")
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = var.opensearch_instance_type
    instance_count         = 1
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.opensearch_master_username
      master_user_password = random_password.opensearch.result
    }
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  vpc_options {
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_security_group.data_services.id]
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "catalog_metadata" {
  name           = "${local.name}-catalog-metadata"
  billing_mode   = "PROVISIONED"
  hash_key       = "GameId"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "GameId"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.ecr_repositories)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name}-platform-logs"
  tags   = local.common_tags
}

data "aws_iam_policy_document" "catalog_dynamodb" {
  statement {
    sid    = "CatalogDynamoDbAccess"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.catalog_metadata.arn]
  }
}

resource "aws_iam_policy" "catalog_dynamodb" {
  name   = "${local.name}-catalog-dynamodb"
  policy = data.aws_iam_policy_document.catalog_dynamodb.json
  tags   = local.common_tags
}

module "catalog_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name = "${local.name}-catalog-irsa"

  role_policy_arns = {
    dynamodb = aws_iam_policy.catalog_dynamodb.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.platform_namespace}:catalog-api"]
    }
  }

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "application" {
  for_each = local.secret_payloads

  name = "fcg/${var.environment}/${each.key}"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "application" {
  for_each = local.secret_payloads

  secret_id     = aws_secretsmanager_secret.application[each.key].id
  secret_string = jsonencode(each.value)
}

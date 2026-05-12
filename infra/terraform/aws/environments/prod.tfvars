aws_region         = "us-east-1"
environment        = "prod"
project_name       = "fcg"
platform_namespace = "fcg-platform"
cluster_version    = "1.35"
# Adicione aqui o ARN do IAM user/role que precisa acessar o EKS pelo console/kubectl.
# eks_admin_principal_arns = ["arn:aws:iam::<ACCOUNT_ID>:user/<USER_NAME>"]
public_subnet_cidrs      = ["10.42.0.0/24", "10.42.1.0/24"]
private_subnet_cidrs     = ["10.42.10.0/24", "10.42.11.0/24"]
node_instance_types      = ["m7i-flex.large"]
node_group_min_size      = 2
node_group_desired_size  = 2
node_group_max_size      = 2
db_instance_class        = "db.t3.micro"
redis_node_type          = "cache.t3.micro"
opensearch_instance_type = "t3.small.search"

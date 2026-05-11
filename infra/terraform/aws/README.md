# AWS Terraform — main stack

Provisiona a base da Fase 4 na AWS:

- `VPC` com 2 AZs, subnets públicas e privadas
- `EKS` com node group gerenciado, `enable_cluster_creator_admin_permissions = true` (caller vira admin via Access Entry)
- Add-ons: `AWS Load Balancer Controller`, `External Secrets`, `Metrics Server` e `Argo CD`
- `ECR` para `frontend-web`, `gateway-api`, `users-api`, `catalog-api`, `payments-api`, `notifications-api`
- `RDS PostgreSQL` consolidado para `UsersAPI` e `CatalogAPI`
- `RabbitMQ` in-cluster via Helm, com credenciais no Secrets Manager
- `ElastiCache Redis`
- `Amazon OpenSearch`
- `DynamoDB`
- `Secrets Manager`
- `IRSA` para o `CatalogAPI`

## Pré-requisito

Aplicar primeiro o [stack bootstrap](../bootstrap/README.md) que cria o bucket de state, a tabela DynamoDB de lock e a role IAM consumida pelo CI.

## Uso local (debug)

```powershell
cd infra/terraform/aws
terraform init `
  -backend-config="bucket=<TF_STATE_BUCKET>" `
  -backend-config="key=aws/prod/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=<TF_LOCK_TABLE>" `
  -backend-config="encrypt=true"
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

Em produção, este `apply` é executado pelo workflow `.github/workflows/terraform-aws.yml` ao push em `master`.

## Acesso ao EKS

O cluster mantém acesso admin para o usuário `fcg-bootstrap-admin` e permite adicionar outros IAM users/roles via Access Entries.
Para liberar seu usuário no console do EKS e no `kubectl`, inclua o ARN em `environments/prod.tfvars`:

```hcl
eks_admin_principal_arns = [
  "arn:aws:iam::<ACCOUNT_ID>:user/<USER_NAME>"
]
```

Depois aplique o stack:

```powershell
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## Observações

- `environments/prod.tfvars` contém apenas parâmetros não sensíveis.
- Credenciais de banco, JWT, RabbitMQ e OpenSearch são geradas pelo Terraform e publicadas no `Secrets Manager`.
- O Terraform não cria Amazon MQ no perfil Free Tier; o chart Helm sobe um RabbitMQ leve dentro do EKS como `rabbitmq-service:5672`.
- O chart Helm em `deploy/helm/fcg-platform` consome esses segredos via `External Secrets` e roda um Job idempotente para criar os databases lógicos no RDS consolidado.
- O script `scripts/render-values.sh` substitui placeholders em `values-prod.yaml` (account ID, IRSA ARN) usando `terraform output -json`.

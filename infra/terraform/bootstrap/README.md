# Bootstrap stack

Cria os pré-requisitos da plataforma — **uma única vez**, com credenciais de admin local na AWS:

- S3 bucket + DynamoDB table para o **state remoto** do stack `infra/terraform/aws`
- Provedor OIDC do GitHub Actions
- Role IAM (`fcg-prod-github-actions`) assumida via `aws-actions/configure-aws-credentials`
- Política agregada com permissões para Terraform + push ECR

## Uso

```powershell
cd infra/terraform/bootstrap
cp environments/prod.tfvars.example environments/prod.tfvars
# editar github_org

terraform init
terraform apply -var-file=environments/prod.tfvars
```

Outputs relevantes:

| Output | Onde usar |
|--------|-----------|
| `github_actions_role_arn` | GitHub → Settings → Secrets → `AWS_GITHUB_ROLE_ARN` (em todos os 5 repos) |
| `tfstate_bucket` | GitHub → Settings → Variables → `TF_STATE_BUCKET` (Orchestrator) |
| `tfstate_lock_table` | GitHub → Settings → Variables → `TF_LOCK_TABLE` (Orchestrator) |

State do bootstrap fica **local** (`terraform.tfstate`) — não migre para o S3 que ele mesmo cria.

## Re-execução

`terraform apply` é idempotente; rode novamente para adicionar repositórios em `github_repos` ou rotacionar o thumbprint OIDC.

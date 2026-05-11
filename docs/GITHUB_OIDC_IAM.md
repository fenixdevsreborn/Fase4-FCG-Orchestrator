# GitHub Actions → AWS (OIDC)

> **Nota.** Esta configuração agora é provisionada automaticamente pelo stack [`infra/terraform/bootstrap`](../infra/terraform/bootstrap/README.md). Este documento permanece como **referência** caso queira recriar manualmente ou auditar o que foi criado.

Use este guia para criar a role assumida por `aws-actions/configure-aws-credentials` com `role-to-assume: ${{ secrets.AWS_GITHUB_ROLE_ARN }}`.

## 1. Provedor OIDC no IAM

- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com` (padrão GitHub)

## 2. Trust policy da role (exemplo)

Restrinja `sub` ao repositório e, se quiser, à branch `refs/heads/master`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ORG/Fase4-FCG-Orchestrator:*"
        }
      }
    }
  ]
}
```

Para as APIs (`Fase4-FCG-UsersAPI`, `Fase4-FCG-CatalogAPI`, `Fase4-FCG-PaymentsAPI`, `Fase4-FCG-NotificationsAPI`), crie **roles separadas** ou amplie o `StringLike` com vários `repo:ORG/...` (ou um padrão `repo:ORG/*` com cuidado).

## 3. Permissões anexas (mínimo orientativo)

| Uso | Exemplos |
|-----|-----------|
| Push ECR | `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` nos repositórios da plataforma |
| Terraform | `ec2:*`, `eks:*`, `iam:*` (limitado), `rds:*`, `elasticache:*`, `opensearch:*`, `dynamodb:*`, `secretsmanager:*`, etc., conforme recursos em `main.tf` |
| Leitura EKS (opcional em CI) | `eks:DescribeCluster` |

Ajuste com políticas geridas ou JSON mínimo por ambiente; prefira **permissões por recurso** (ARN de ECR, cluster EKS) em produção.

## 4. Secret no GitHub

Em cada repositório que executa a pipeline: **Settings → Secrets and variables → Actions** → criar `AWS_GITHUB_ROLE_ARN` com o ARN da role (ex.: `arn:aws:iam::123456789012:role/github-actions-fcg`).

## 5. Backend do estado Terraform

O diretório `infra/terraform/aws` não define `backend` remoto por defeito. Para equipa/CI, configure um bloco `backend "s3"` (bucket, chave, região, tabela DynamoDB para lock) antes de `terraform init` partilhado.

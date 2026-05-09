# Deploy automático na AWS — guia ponta-a-ponta

Este guia descreve **o que é automatizado** e **o que continua manual** na entrega da plataforma FCG na AWS.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ One-time bootstrap (manual local) → recurring CI/CD (automático)         │
│                                                                          │
│  [terraform/bootstrap]   →   [Orchestrator CI: terraform/aws]            │
│       cria OIDC + role            terraform apply + render values        │
│       cria S3/DynamoDB              push commit em main                  │
│                                                                          │
│  [APIs CI/CD]            →   [Argo CD (no cluster)]                      │
│       build + push ECR            sync da values-prod.yaml               │
│       atualiza values             rolling update sem downtime            │
└──────────────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos manuais (executar uma única vez)

| # | Ação | Onde |
|---|------|------|
| 1 | Conta AWS com permissão administrativa para o bootstrap | Workstation local |
| 2 | Repositórios GitHub criados (Orchestrator + 4 APIs), branch `main` | github.com |
| 3 | Aplicar **stack bootstrap** (cria OIDC, IAM role, bucket de state, tabela de lock) | Workstation local |
| 4 | Configurar GitHub secrets/variables (ver lista abaixo) | GitHub UI / `gh` CLI |
| 5 | Atualizar `repoURL` em `gitops/argocd/*.yaml` para o repo real do Orchestrator | git commit |

Tudo a partir do passo 6 é **disparado por push** e não exige intervenção.

## 1. Bootstrap stack (manual, único)

```powershell
cd Fase2-Orchestrator/infra/terraform/bootstrap
cp environments/prod.tfvars.example environments/prod.tfvars
# Editar github_org="<seu-org>" e github_repos=[...]

terraform init
terraform apply -var-file=environments/prod.tfvars
```

Outputs:

```
github_actions_role_arn = "arn:aws:iam::123456789012:role/fcg-prod-github-actions"
tfstate_bucket          = "fcg-prod-tfstate-123456789012"
tfstate_lock_table      = "fcg-prod-tfstate-lock"
oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
```

> **State do bootstrap fica local.** Não migrar para o S3 que ele mesmo cria (chicken/egg).

## 2. Configurar GitHub (manual, único)

### No repositório `Fase2-Orchestrator`

| Tipo | Nome | Valor (exemplo) |
|------|------|-----------------|
| Secret | `AWS_GITHUB_ROLE_ARN` | `arn:aws:iam::123456789012:role/fcg-prod-github-actions` |
| Variable | `TF_STATE_BUCKET` | `fcg-prod-tfstate-123456789012` |
| Variable | `TF_LOCK_TABLE` | `fcg-prod-tfstate-lock` |
| Variable | `GITOPS_REPO_URL` | `https://github.com/<org>/Fase2-Orchestrator.git` |
| Environment | `prod` | (opcional) required reviewers para gate antes do `apply` |

### Em cada API (`Fase2-UsersAPI`, `Fase2-CatalogAPI`, `Fase2-PaymentsAPI`, `Fase2-NotificationsAPI`)

| Tipo | Nome | Valor |
|------|------|-------|
| Secret | `AWS_GITHUB_ROLE_ARN` | mesmo ARN do Orchestrator |
| Secret | `GITOPS_TOKEN` | PAT com `contents:write` no repo Orchestrator |
| Variable | `GITOPS_REPOSITORY` | `<org>/Fase2-Orchestrator` |

> Se `main` do Orchestrator estiver protegida, adicione a conta de service que detém o `GITOPS_TOKEN` ao bypass de proteção, ou troque para um GitHub App.

## 3. Atualizar manifests Argo CD (manual, único)

Editar **uma vez** as duas linhas placeholder e commitar:

- `gitops/argocd/fcg-platform-application.yaml` → `repoURL`
- `gitops/argocd/fcg-platform-project.yaml` → `sourceRepos`

> Após o primeiro `terraform apply` automático, o script `scripts/render-values.sh` substitui esses placeholders se a variável `GITOPS_REPO_URL` estiver definida — você pode pular essa edição manual se confiar no render automático.

## 4. Push para `main` do Orchestrator (automático daqui para frente)

O workflow `.github/workflows/terraform-aws.yml` faz, ao push em `main`:

1. `terraform plan` (job `plan`)
2. `terraform apply` (job `apply`, gated por `environment: prod`)
3. `terraform output -json > tf-outputs.json`
4. `scripts/render-values.sh` substitui:
   - `111111111111.dkr.ecr.<region>.amazonaws.com` → registry real
   - `arn:aws:iam::111111111111:role/...catalog-irsa...` → ARN IRSA real
   - `https://github.com/your-org/your-repo.git` → `vars.GITOPS_REPO_URL`
5. Commit automático do `values-prod.yaml` e dos manifests Argo CD ajustados

## 5. Instalar Argo CD `Application` (uma vez)

Após o primeiro `terraform apply`, conecte ao cluster e aplique os manifests do Argo CD:

```powershell
aws eks update-kubeconfig --region us-east-1 --name fcg-prod
kubectl apply -f gitops/argocd/fcg-platform-project.yaml
kubectl apply -f gitops/argocd/fcg-platform-application.yaml
```

> O Argo CD em si é instalado pelo próprio Terraform (módulo `eks-blueprints-addons` com `enable_argocd = true`). O passo aqui é só registrar o `AppProject` e a `Application` que apontam para este repositório.

## 6. Deploy contínuo das APIs (totalmente automático)

Cada push em `main` numa API:

1. `dotnet build` + `dotnet test`
2. `nuget audit` (falha em High/Critical)
3. `docker build` + push em ECR (tag = `${GITHUB_SHA::12}`)
4. `trivy` no image (falha em High/Critical)
5. `git checkout` no Orchestrator + edita `values-prod.yaml` para a nova tag
6. `git commit && git push` — Argo CD detecta e faz rolling update

## Manual recurring (raro)

| Quando | Ação |
|--------|------|
| Adicionar novo repo de API | `terraform apply` no bootstrap com novo item em `github_repos` |
| Rotacionar thumbprint OIDC | `terraform apply` no bootstrap |
| Mudar instance types/tamanho do node group | editar `environments/prod.tfvars` e push em `main` |
| Acesso kubectl de outro IAM principal | adicionar `access_entries` em `main.tf` (módulo EKS v20) |

## Troubleshooting

| Sintoma | Causa provável | Fix |
|---------|----------------|-----|
| `terraform apply` falha com `Unauthorized` ao instalar addons | EKS não concedeu admin ao caller | confirmar `enable_cluster_creator_admin_permissions = true` em `main.tf` |
| `ExternalSecret` em `SecretSyncedError` | SA do `external-secrets` não tem IRSA | verificar `kubectl -n external-secrets get sa` e ajustar `global.externalSecretStore.serviceAccountRef.name` em `values.yaml` |
| Argo CD `OutOfSync` permanente em images com tag `initial` | nenhuma API rodou CI ainda | rodar `workflow_dispatch` na CI das APIs |
| Push de imagem retorna `tag immutable, exists` | duplicidade de SHA | normal — ECR está com `IMMUTABLE`, basta commit novo |
| `terraform plan` reclama backend | secrets `TF_STATE_BUCKET`/`TF_LOCK_TABLE` ausentes | configurar como **variables** (não secrets) no Orchestrator |

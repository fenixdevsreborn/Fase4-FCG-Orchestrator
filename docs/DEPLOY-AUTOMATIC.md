# Deploy automático na AWS — guia ponta-a-ponta

> **Branch alvo de TODAS as pipelines: `master`.**
> **Registries:** AWS ECR (privado, exigido pelo Tech Challenge) **+ Docker Hub** (público, em paralelo).

```
┌──────────────────────────────────────────────────────────────────────────┐
│ One-time bootstrap (manual local) → recurring CI/CD (automático)         │
│                                                                          │
│  [terraform/bootstrap]   →   [Orchestrator CI: terraform/aws]            │
│       cria OIDC + role            terraform apply + render values        │
│       cria S3/DynamoDB              push commit em master                │
│                                                                          │
│  [APIs CI/CD]            →   [Argo CD (no cluster)]                      │
│       build + push ECR            sync da values-prod.yaml               │
│       + push Docker Hub           rolling update sem downtime            │
│       atualiza values             (via image: ECR no Helm)               │
└──────────────────────────────────────────────────────────────────────────┘
```

## Pré-requisitos manuais (executar uma única vez)

| # | Ação | Onde |
|---|------|------|
| 1 | Conta AWS com permissão administrativa para o bootstrap | Workstation local |
| 2 | Conta Docker Hub + 5 repositórios criados (`fcg-*`) + PAT Read/Write | hub.docker.com |
| 3 | 5 repositórios GitHub criados (Orchestrator + 4 APIs), branch `master` | github.com |
| 4 | Aplicar **stack bootstrap** (cria OIDC, IAM role, bucket de state, tabela de lock) | Workstation local |
| 5 | Configurar GitHub secrets/variables (ver lista abaixo) | GitHub UI / `gh` CLI |
| 6 | Atualizar `repoURL` em `gitops/argocd/*.yaml` para o repo real do Orchestrator | git commit |

> Detalhe completo do checklist em [MANUAL-STEPS.md](MANUAL-STEPS.md). Tudo a partir do passo 7 é **disparado por push em `master`** e não exige intervenção.

## 1. Bootstrap stack (manual, único)

```powershell
cd Fase4-FCG-Orchestrator/infra/terraform/bootstrap
Copy-Item environments/prod.tfvars.example environments/prod.tfvars
# Editar github_org="<seu-org>" (github_repos já vem com nomes Fase4-FCG-*)

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

### No repositório `Fase4-FCG-Orchestrator`

| Tipo | Nome | Valor (exemplo) |
|------|------|-----------------|
| Secret | `AWS_GITHUB_ROLE_ARN` | `arn:aws:iam::123456789012:role/fcg-prod-github-actions` |
| Secret | `DOCKERHUB_USERNAME` | `seuusuario` |
| Secret | `DOCKERHUB_TOKEN` | PAT Docker Hub (Read & Write) |
| Variable | `TF_STATE_BUCKET` | `fcg-prod-tfstate-123456789012` |
| Variable | `TF_LOCK_TABLE` | `fcg-prod-tfstate-lock` |
| Variable | `GITOPS_REPO_URL` | `https://github.com/<org>/Fase4-FCG-Orchestrator.git` |
| Environment | `prod` | (opcional) required reviewers para gate antes do `apply` |

### Em cada API (`Fase4-FCG-UsersAPI`, `Fase4-FCG-CatalogAPI`, `Fase4-FCG-PaymentsAPI`, `Fase4-FCG-NotificationsAPI`)

| Tipo | Nome | Valor |
|------|------|-------|
| Secret | `AWS_GITHUB_ROLE_ARN` | mesmo ARN do Orchestrator |
| Secret | `DOCKERHUB_USERNAME` | username Docker Hub |
| Secret | `DOCKERHUB_TOKEN` | PAT Docker Hub (Read & Write) |
| Secret | `GITOPS_TOKEN` | PAT GitHub com `contents:write` no repo Orchestrator |
| Variable | `GITOPS_REPOSITORY` | `<org>/Fase4-FCG-Orchestrator` |

> Se `master` do Orchestrator estiver protegida, adicione a conta de service que detém o `GITOPS_TOKEN` ao bypass de proteção, ou troque para um GitHub App.

## 3. Atualizar manifests Argo CD (manual, único)

Editar **uma vez** as duas linhas placeholder e commitar:

- `gitops/argocd/fcg-platform-application.yaml` → `repoURL` (e confirmar `targetRevision: master`)
- `gitops/argocd/fcg-platform-project.yaml` → `sourceRepos`

> Após o primeiro `terraform apply` automático, `scripts/render-values.sh` substitui esses placeholders se a variável `GITOPS_REPO_URL` estiver definida — você pode pular essa edição manual se confiar no render automático.

## 4. Push para `master` do Orchestrator (automático daqui para frente)

O workflow `.github/workflows/terraform-aws.yml` faz, ao push em `master`:

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

Cada push em `master` numa API:

1. `dotnet build` + `dotnet test`
2. `nuget audit` (falha em High/Critical)
3. `docker build` + push em ECR (tag = `${GITHUB_SHA::12}`)
4. **`docker tag` + push em Docker Hub** (`<user>/fcg-<service>:<sha>` e `:latest`)
5. `trivy` na imagem (falha em High/Critical)
6. `git checkout` no Orchestrator + edita `values-prod.yaml` para a nova tag (refere-se ao registry ECR; Docker Hub é só publicação paralela)
7. `git commit && git push` — Argo CD detecta e faz rolling update

## Manual recurring (raro)

| Quando | Ação |
|--------|------|
| Adicionar novo repo de API | `terraform apply` no bootstrap com novo item em `github_repos` + criar repo Docker Hub |
| Rotacionar thumbprint OIDC | `terraform apply` no bootstrap |
| Rotacionar `DOCKERHUB_TOKEN` | Gerar novo PAT no Docker Hub e atualizar secret nos 5 repos |
| Mudar instance types/tamanho do node group | editar `environments/prod.tfvars` e push em `master` |
| Acesso kubectl de outro IAM principal | adicionar `access_entries` em `main.tf` (módulo EKS v20) |

## Troubleshooting

| Sintoma | Causa provável | Fix |
|---------|----------------|-----|
| `terraform apply` falha com `Unauthorized` ao instalar addons | EKS não concedeu admin ao caller | confirmar `enable_cluster_creator_admin_permissions = true` em `main.tf` |
| `ExternalSecret` em `SecretSyncedError` | SA do `external-secrets` não tem IRSA | verificar `kubectl -n external-secrets get sa` e ajustar `global.externalSecretStore.serviceAccountRef.name` em `values.yaml` |
| Argo CD `OutOfSync` permanente em images com tag `initial` | nenhuma API rodou CI ainda | rodar `workflow_dispatch` na CI das APIs |
| Push de imagem retorna `tag immutable, exists` | duplicidade de SHA | normal — ECR está com `IMMUTABLE`, basta commit novo |
| `terraform plan` reclama backend | secrets `TF_STATE_BUCKET`/`TF_LOCK_TABLE` ausentes | configurar como **variables** (não secrets) no Orchestrator |
| `docker login` no step Docker Hub falha 401 | Token revogado/expirado ou username errado | regerar PAT, atualizar `DOCKERHUB_TOKEN` em todos os 5 repos |
| Pipeline não dispara no push | branch padrão ainda é `main` ou push foi para outra branch | trocar default branch em Settings → Default branch para `master` |

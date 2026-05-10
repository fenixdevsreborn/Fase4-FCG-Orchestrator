# Passos manuais (executar uma vez)

> **Sequência de setup** → [1. Bootstrap](BOOTSTRAP.md) → [2. GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) → [3. Secrets](SECRETS-MANAGEMENT.md) → **Você está aqui: [4. Configurar + Deploy]**

> **Branch alvo:** todas as pipelines disparam em **`master`**.
> **Registries de imagem:** AWS ECR (privado, exigido pelo Tech Challenge) **+ Docker Hub** (público, para portabilidade/demo).
> **Repositórios GitHub:** padrão `Fase4-FCG-*`.

Este checklist cobre **tudo o que NÃO é automatizado** pelas pipelines. Após esta lista, todo deploy é disparado por `git push` em `master`.

---

## ✅ Checklist resumido

### Pré-requisitos (antes do bootstrap)
- [ ] **Usuário IAM `fcg-bootstrap-admin`** criado com `AdministratorAccess` e **Access Key** gerada (selecionar "Outros" na tela de criação) — [BOOTSTRAP.md](BOOTSTRAP.md)
- [ ] **Conta Docker Hub** + Personal Access Token (PAT Read & Write)
- [ ] **5 repositórios GitHub** criados com branch padrão = `master`
- [ ] **5 repositórios Docker Hub** criados (`<user>/fcg-*-api`)
- [ ] **GitHub App `FCG GitOps`** criado e `.pem` baixado — [SECURITY-SETUP.md §1](SECURITY-SETUP.md)

### Bootstrap (uma vez, automatizado via GitHub Actions)
- [ ] Configurar secrets temporários no Orchestrator: `BOOTSTRAP_AWS_ACCESS_KEY_ID`, `BOOTSTRAP_AWS_SECRET_ACCESS_KEY`
- [ ] *(Opcional)* Configurar `GH_ADMIN_PAT` para auto-setup de todos os repos
- [ ] *(Opcional)* Criar environment `bootstrap` com required reviewers
- [ ] **Disparar workflow `bootstrap-aws`** via Actions → bootstrap-aws → Run workflow — [BOOTSTRAP.md](BOOTSTRAP.md)
- [ ] **Excluir** `BOOTSTRAP_AWS_ACCESS_KEY_ID` e `BOOTSTRAP_AWS_SECRET_ACCESS_KEY` do GitHub e da AWS

### Configuração de secrets (uma vez)
- [ ] **GitHub Org Secrets** (se organização) OU **Doppler** (se conta pessoal) — [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md)
- [ ] **GitHub secrets/variables** nos 5 repositórios (se não usou auto-config do bootstrap)
- [ ] **Editar `repoURL`** em `gitops/argocd/*.yaml` (ou confiar no render automático)

### Deploy inicial
- [ ] **Push em `master` do Orchestrator** → dispara `terraform apply` da plataforma (EKS, ECR, RDS, etc.)
- [ ] **Aprovar** no environment `prod` (se configurado)
- [ ] **`workflow_dispatch`** uma vez em cada API para subir primeiras imagens no ECR/Docker Hub
- [ ] **`kubectl apply -f gitops/argocd/`** no cluster para registrar Argo CD Application

### Pós-setup (segurança)
- [ ] **Branch protection** em `master` nos 5 repos — [SECURITY-SETUP.md §2](SECURITY-SETUP.md)
- [ ] **Dependabot + secret scanning** — [SECURITY-SETUP.md §3](SECURITY-SETUP.md)

---

## 1) Repositórios GitHub obrigatórios

Crie os 5 repositórios na sua organização GitHub com branch padrão = `master`:

> URL direta para criar: `https://github.com/new`
> Após criar: **Settings → Default branch → master** (se criou com `main`)

| Repositório | Branch padrão | Visibilidade sugerida |
|---|---|---|
| `Fase4-FCG-Orchestrator` | `master` | Privado |
| `Fase4-FCG-UsersAPI` | `master` | Privado |
| `Fase4-FCG-CatalogAPI` | `master` | Privado |
| `Fase4-FCG-PaymentsAPI` | `master` | Privado |
| `Fase4-FCG-NotificationsAPI` | `master` | Privado |

> **Atenção:** se você criou os repos com branch padrão `main`, troque para `master` em **Settings → Branches → Default branch**, ou as pipelines não disparam.

> **Próxima etapa depois dos repos →** [2) Docker Hub](#2-repositórios-docker-hub-obrigatórios)

---

## 2) Repositórios Docker Hub obrigatórios

Os workflows fazem **push paralelo para ECR e Docker Hub**. Crie os 5 repositórios em [https://hub.docker.com](https://hub.docker.com) sob a conta cujo username será usado em `DOCKERHUB_USERNAME`:

| Docker Hub repository | Origem (workflow) |
|---|---|
| `<DOCKERHUB_USERNAME>/fcg-gateway-api` | `Fase4-FCG-Orchestrator` |
| `<DOCKERHUB_USERNAME>/fcg-users-api` | `Fase4-FCG-UsersAPI` |
| `<DOCKERHUB_USERNAME>/fcg-catalog-api` | `Fase4-FCG-CatalogAPI` |
| `<DOCKERHUB_USERNAME>/fcg-payments-api` | `Fase4-FCG-PaymentsAPI` |
| `<DOCKERHUB_USERNAME>/fcg-notifications-api` | `Fase4-FCG-NotificationsAPI` |

Tags publicadas em cada push:
- `:<git_sha_curto>` (12 caracteres) — versão imutável
- `:latest` — ponteiro para a última imagem

### Como criar (UI Docker Hub)

> URL direta: `https://hub.docker.com/repository/create`

1. Login em https://hub.docker.com → **Repositories → Create repository**
2. Nome: `fcg-gateway-api` (visibilidade Public ou Private)
3. Repita para os outros 4

### Como gerar o `DOCKERHUB_TOKEN`

> URL direta: `https://hub.docker.com/settings/security`

1. Docker Hub → **Account Settings → Security → New Access Token**
2. Description: `fcg-ci`
3. Permissions: **Read & Write** (necessário para push)
4. Copie o token (mostrado só uma vez)

> **Próxima etapa →** [3) Bootstrap AWS](#3-bootstrap-aws-stack-único-manual)

---

## 3) Bootstrap AWS (stack único, manual)

> **Guia completo com pré-requisitos (AWS CLI, Terraform, credenciais):** [docs/BOOTSTRAP.md](BOOTSTRAP.md)

Resumo dos comandos:

```powershell
cd Fase4-FCG-Orchestrator/infra/terraform/bootstrap
Copy-Item environments/prod.tfvars.example environments/prod.tfvars
# Edite environments/prod.tfvars: defina github_org="<seu-org>"
# (a lista github_repos já vem com os nomes Fase4-FCG-* corretos)

terraform init
terraform apply -var-file=environments/prod.tfvars
# digitar "yes" quando solicitado
```

Outputs (capture para o passo 4):
```powershell
$ROLE   = terraform output -raw github_actions_role_arn
$BUCKET = terraform output -raw tfstate_bucket
$LOCK   = terraform output -raw tfstate_lock_table
```

> **Importante:** O state do bootstrap fica **local**. Não commite `terraform.tfstate`. Ver BOOTSTRAP.md §5 para detalhes.

> **Próxima etapa →** Antes de configurar os secrets das APIs, crie o GitHub App.
> [Ir para SECURITY-SETUP.md §1 — Criar GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat)

---

## 4) Configurar GitHub secrets/variables

> **Antes de configurar os secrets das APIs:** você precisa do GitHub App criado e do `.pem` em mãos.
> Se ainda não criou: [SECURITY-SETUP.md §1](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat)
>
> **Estratégia de secrets:** se você usa organização GitHub, configure como **GitHub Org Secrets** (uma vez, todos os repos recebem).
> Ver [SECRETS-MANAGEMENT.md → Opção 1](SECRETS-MANAGEMENT.md#opção-1-github-organization-secrets-recomendada-gratuita)

### 4.1 Repositório `Fase4-FCG-Orchestrator`

> URL direta: `https://github.com/<sua-org>/Fase4-FCG-Orchestrator/settings/secrets/actions`

| Tipo | Nome | Valor (exemplo) | Quem usa |
|---|---|---|---|
| Secret | `AWS_GITHUB_ROLE_ARN` | `arn:aws:iam::123456789012:role/fcg-prod-github-actions` | terraform-aws.yml, gateway-api-ci-cd.yml |
| Secret | `DOCKERHUB_USERNAME` | `seuusuario` | gateway-api-ci-cd.yml |
| Secret | `DOCKERHUB_TOKEN` | PAT Docker Hub (Read & Write) | gateway-api-ci-cd.yml |
| Variable | `TF_STATE_BUCKET` | `fcg-prod-tfstate-123456789012` | terraform-aws.yml |
| Variable | `TF_LOCK_TABLE` | `fcg-prod-tfstate-lock` | terraform-aws.yml |
| Variable | `GITOPS_REPO_URL` | `https://github.com/<org>/Fase4-FCG-Orchestrator.git` | terraform-aws.yml (render-values.sh) |
| Environment | `prod` | (opcional) required reviewers | gate manual antes do `apply` |

### 4.2 Cada repo de API (`Fase4-FCG-UsersAPI`, `CatalogAPI`, `PaymentsAPI`, `NotificationsAPI`)

> As pipelines das APIs usam **GitHub App** (não PAT) para fazer commit no Orchestrator.
> Crie o App antes de configurar estes secrets: [SECURITY-SETUP.md §1](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat)
>
> URL direta de secrets de cada API: `https://github.com/<sua-org>/<repo>/settings/secrets/actions`

| Tipo | Nome | Valor | Como obter |
|---|---|---|---|
| Secret | `AWS_GITHUB_ROLE_ARN` | ARN da role IAM | Output do bootstrap |
| Secret | `DOCKERHUB_USERNAME` | username Docker Hub | Seu login em hub.docker.com |
| Secret | `DOCKERHUB_TOKEN` | PAT Docker Hub | hub.docker.com → Account Settings → Security |
| Secret | `GITOPS_APP_PRIVATE_KEY` | conteúdo completo do `.pem` | Arquivo baixado em [SECURITY-SETUP.md §1.2](SECURITY-SETUP.md#12-gerar-a-private-key) |
| Variable | `GITOPS_APP_ID` | ID numérico do GitHub App | Página do App em GitHub → App ID |
| Variable | `GITOPS_REPOSITORY` | `<org>/Fase4-FCG-Orchestrator` | Nome exato do repo Orchestrator |

> Se `master` do Orchestrator estiver protegida, configure o GitHub App como bypass actor.
> [SECURITY-SETUP.md §2](SECURITY-SETUP.md#2-branch-protection-em-master)

### 4.3 Setup automatizado via `gh` CLI

```powershell
# Pré: gh auth login + você tem owner permission nos 5 repos
# Pré: bootstrap Terraform já executado (para capturar ROLE, BUCKET, LOCK)
# Pré: GitHub App criado e .pem baixado (ver SECURITY-SETUP.md §1)
$ORG      = "seu-org"
$ROLE     = terraform output -raw github_actions_role_arn  # rodar dentro de infra/terraform/bootstrap
$BUCKET   = terraform output -raw tfstate_bucket
$LOCK     = terraform output -raw tfstate_lock_table
$DH_USER  = "seu_dockerhub_username"
$DH_TOKEN = "<PAT Docker Hub Read & Write>"
$APP_ID   = "<ID numérico do GitHub App FCG GitOps>"
$APP_PEM  = Get-Content "caminho\para\fcg-gitops.pem" -Raw

# --- Orchestrator ---
gh secret   set AWS_GITHUB_ROLE_ARN --body "$ROLE"     --repo "$ORG/Fase4-FCG-Orchestrator"
gh secret   set DOCKERHUB_USERNAME  --body "$DH_USER"  --repo "$ORG/Fase4-FCG-Orchestrator"
gh secret   set DOCKERHUB_TOKEN     --body "$DH_TOKEN" --repo "$ORG/Fase4-FCG-Orchestrator"
gh variable set TF_STATE_BUCKET     --body "$BUCKET"   --repo "$ORG/Fase4-FCG-Orchestrator"
gh variable set TF_LOCK_TABLE       --body "$LOCK"     --repo "$ORG/Fase4-FCG-Orchestrator"
gh variable set GITOPS_REPO_URL     --body "https://github.com/$ORG/Fase4-FCG-Orchestrator.git" --repo "$ORG/Fase4-FCG-Orchestrator"

# --- APIs (usam GitHub App para GitOps write) ---
$APIS = @("Fase4-FCG-UsersAPI","Fase4-FCG-CatalogAPI","Fase4-FCG-PaymentsAPI","Fase4-FCG-NotificationsAPI")
foreach ($r in $APIS) {
  gh secret   set AWS_GITHUB_ROLE_ARN    --body "$ROLE"     --repo "$ORG/$r"
  gh secret   set DOCKERHUB_USERNAME     --body "$DH_USER"  --repo "$ORG/$r"
  gh secret   set DOCKERHUB_TOKEN        --body "$DH_TOKEN" --repo "$ORG/$r"
  gh secret   set GITOPS_APP_PRIVATE_KEY --body "$APP_PEM"  --repo "$ORG/$r"
  gh variable set GITOPS_APP_ID          --body "$APP_ID"   --repo "$ORG/$r"
  gh variable set GITOPS_REPOSITORY      --body "$ORG/Fase4-FCG-Orchestrator" --repo "$ORG/$r"
}
```

> **Próxima etapa depois dos secrets →** [5) Atualizar manifests Argo CD](#5-atualizar-manifests-argo-cd-uma-vez)

---

## 5) Atualizar manifests Argo CD (uma vez)

Editar **uma vez** o placeholder `your-org/your-repo` e commitar:

- Arquivo: `gitops/argocd/fcg-platform-application.yaml` → altere `repoURL` e confirme `targetRevision: master`
- Arquivo: `gitops/argocd/fcg-platform-project.yaml` → altere `sourceRepos`

```yaml
# gitops/argocd/fcg-platform-application.yaml — alterar:
  source:
    repoURL: https://github.com/<sua-org>/Fase4-FCG-Orchestrator.git   # <- trocar
    targetRevision: master
```

> Após o primeiro `terraform apply` automático, `scripts/render-values.sh` substitui esses placeholders se `vars.GITOPS_REPO_URL` estiver definida. Você pode pular essa edição se confiar no render automático, mas a `targetRevision: master` precisa estar correta antes do Argo CD ser registrado.

> **Próxima etapa →** [6) Push em master](#6-push-em-master-do-orchestrator-a-partir-daqui-é-automático)

---

## 6) Push em `master` do Orchestrator (a partir daqui é automático)

```powershell
cd Fase4-FCG-Orchestrator
git checkout -b master
git add .
git commit -m "chore: initial fase 4 platform"
git push -u origin master
```

A pipeline `terraform-aws.yml` irá:
1. Helm lint + helm template (valida o chart)
2. `terraform plan`
3. `terraform apply` (gated por environment `prod` se configurado)
4. Capturar outputs e renderizar `values-prod.yaml` + manifests Argo CD
5. Commitar de volta os arquivos renderizados

> **Próxima etapa →** [7) Primeira imagem de cada API](#7-disparar-primeira-imagem-em-cada-api)

---

## 7) Disparar primeira imagem em cada API

Cada API precisa rodar a pipeline pelo menos uma vez para popular ECR + Docker Hub.

> URL direta para disparar: `https://github.com/<sua-org>/<repo>/actions`
> Clique no workflow → **Run workflow** → Branch: `master` → **Run workflow**

Via `gh` CLI:
```powershell
$ORG = "sua-org"
# Disparar manualmente cada API
gh workflow run "users-api-ci-cd.yml"         --repo "$ORG/Fase4-FCG-UsersAPI"         --ref master
gh workflow run "catalog-api-ci-cd.yml"       --repo "$ORG/Fase4-FCG-CatalogAPI"       --ref master
gh workflow run "payments-api-ci-cd.yml"      --repo "$ORG/Fase4-FCG-PaymentsAPI"      --ref master
gh workflow run "notifications-api-ci-cd.yml" --repo "$ORG/Fase4-FCG-NotificationsAPI" --ref master
```

> **Próxima etapa →** [8) Registrar Argo CD no cluster](#8-conectar-argo-cd-ao-cluster)

---

## 8) Conectar Argo CD ao cluster

```powershell
# 1. Conectar ao cluster EKS (após terraform apply criar o EKS)
aws eks update-kubeconfig --region us-east-1 --name fcg-prod

# 2. Registrar o AppProject e a Application
kubectl apply -f gitops/argocd/fcg-platform-project.yaml
kubectl apply -f gitops/argocd/fcg-platform-application.yaml

# 3. Verificar sincronização
kubectl -n argocd get application fcg-platform
```

> O Argo CD em si é instalado pelo Terraform (`eks-blueprints-addons` com `enable_argocd = true`). Este passo apenas registra o App/Project.

> **Setup concluído.** A partir daqui todo deploy é automático via push em `master`.
> Para o fluxo automático completo: [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md)

---

## Itens que continuam manuais por design

| Item | Por quê | Doc | Frequência |
|------|---------|-----|-----------|
| Criar usuário IAM + Access Key | Necessário para bootstrap | [BOOTSTRAP.md](BOOTSTRAP.md) | 1x |
| Bootstrap AWS via `bootstrap-aws` workflow | Chicken/egg — cria o OIDC | [BOOTSTRAP.md](BOOTSTRAP.md) | 1x |
| Criação dos 5 repos GitHub | Fora do escopo Terraform | — | 1x |
| Criação dos 5 repos Docker Hub | Docker Hub não tem API Terraform | — | 1x |
| Criação do GitHub App `FCG GitOps` + `.pem` | Credencial de App | [SECURITY-SETUP.md §1](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) | 1x |
| Geração de `DOCKERHUB_TOKEN` (PAT) | Docker Hub não tem OIDC | [hub.docker.com/settings/security](https://hub.docker.com/settings/security) | Rotação 90 dias |
| Aprovação no environment `prod` | Gate humano (opcional) | — | A cada apply |
| `kubectl apply -f gitops/argocd/` | Argo CD registrado uma vez | [§8 acima](#8-conectar-argo-cd-ao-cluster) | 1x |

---

## Referências cruzadas

| Documento | Conteúdo |
|---|---|
| [BOOTSTRAP.md](BOOTSTRAP.md) | Bootstrap AWS: via GitHub Actions (recomendado) ou local |
| [SECURITY-SETUP.md](SECURITY-SETUP.md) | GitHub App, branch protection, secret scanning, rotação |
| [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md) | Cloudflare (por que não), Doppler, GitHub Org Secrets |
| [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md) | Fluxo automático completo pós-setup |
| [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) | Rollback, restore RDS, reconstrução de cluster |
| [ENV-VARS.md](ENV-VARS.md) | Padrão de variáveis de ambiente por serviço |
| [FASE4-COMPLIANCE.md](FASE4-COMPLIANCE.md) | Mapa de compliance com o Tech Challenge |
| [IMPROVEMENTS.md](IMPROVEMENTS.md) | Melhorias implementadas e pendentes |

---

> **Navegação:**
> ← [3. Secrets](SECRETS-MANAGEMENT.md) | **Você está aqui: Configurar + Deploy** | [Fluxo automático →](DEPLOY-AUTOMATIC.md)

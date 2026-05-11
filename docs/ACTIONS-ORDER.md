# Ordem de Execução dos GitHub Actions Workflows

Guia de referência para a ordem correta de execução de todos os workflows CI/CD da plataforma FCG Fase 4.

---

## Mapa completo dos workflows

| # | Repo | Workflow | Trigger | O que faz |
|---|---|---|---|---|
| 01 | Orchestrator | `bootstrap-aws` | Manual (workflow_dispatch) | Cria OIDC, IAM role, S3, DynamoDB na AWS + configura secrets nos repos |
| 02 | Orchestrator | `terraform-aws` | Push em `master` (paths: infra/ ou deploy/helm/) | Cria EKS, ECR, RDS, Redis, OpenSearch, DynamoDB, secrets do RabbitMQ interno, Argo CD — e registra o Argo CD no cluster automaticamente |
| 03 | Orchestrator | `gateway-api-ci-cd` | Push em `master` (paths: src/) ou manual | Build + push Gateway YARP → ECR + Docker Hub → atualiza values-prod.yaml |
| 04a | UsersAPI | `users-api-ci-cd` | Push em `master` ou manual | Build + test + push → ECR + Docker Hub → atualiza values-prod.yaml |
| 04b | CatalogAPI | `catalog-api-ci-cd` | Push em `master` ou manual | Build + test + push → ECR + Docker Hub → atualiza values-prod.yaml |
| 04c | PaymentsAPI | `payments-api-ci-cd` | Push em `master` ou manual | Build + push → ECR + Docker Hub → atualiza values-prod.yaml |
| 04d | NotificationsAPI | `notifications-api-ci-cd` | Push em `master` ou manual | Build + test + push → ECR + Docker Hub → atualiza values-prod.yaml |
| 04e | Frontend | `frontend-ci-cd` | Push em `master` ou manual | Build Nuxt + push → ECR → atualiza values-prod.yaml |
| 05 | Orchestrator | `release` | Push em `master` (exclui docs e valores de CI) | Abre PR de release semântico (Conventional Commits) |
| 06 | Orchestrator | `destroy-aws` | Manual (workflow_dispatch) | Destrói TODOS os recursos AWS em ordem segura |

---

## Etapa 01 — Bootstrap AWS (`bootstrap-aws`)

**Quando rodar:** uma única vez antes de qualquer deploy. Pré-requisito para os demais.

**Trigger:** Actions → Orchestrator → `.github/workflows/bootstrap.yml` → Run workflow

**Inputs obrigatórios:**
```
github_org:             fenixdevsreborn
dockerhub_user:         <seu username Docker Hub>
gitops_app_id:          3660554
auto_configure_secrets: true
```

**O que cria:**
- OIDC Provider na AWS
- IAM Role `fcg-prod-github-actions`
- S3 bucket de state Terraform
- DynamoDB lock table
- Configura automaticamente todos os GitHub secrets/variables nos 5 repos

**Após rodar:** excluir `BOOTSTRAP_AWS_ACCESS_KEY_ID` e `BOOTSTRAP_AWS_SECRET_ACCESS_KEY` dos secrets do GitHub.

---

## Etapa 02 — Plataforma AWS (`terraform-aws`)

**Quando rodar:** após o bootstrap, para criar a infraestrutura de produção.

**Trigger automático:** push em `master` no Orchestrator que modifique arquivos em:
- `infra/terraform/aws/**`
- `deploy/helm/fcg-platform/**`

**Trigger manual:**
```
Actions → Orchestrator → terraform-aws → Run workflow
```

**Jobs em sequência:**
1. `validate` — helm lint + helm template
2. `plan` — terraform plan (com force-unlock automático de locks stale)
3. `apply` — terraform apply + render values-prod.yaml + **registra Argo CD automaticamente**

**O que cria (~25 min):**
- EKS cluster `fcg-prod` (Kubernetes 1.35, até 2 nós `m7i-flex.large`)
- 6 repositórios ECR
- RDS PostgreSQL consolidado (`users_db` e `catalogdb` criados por Job Kubernetes)
- Secrets do RabbitMQ interno; o broker roda no Helm chart como `rabbitmq-service:5672`
- ElastiCache Redis
- Amazon OpenSearch
- DynamoDB (catalog metadata)
- Secrets Manager (todas as senhas geradas pelo Terraform)
- ALB Controller, External Secrets Operator, Argo CD, Fluentbit (via eks_blueprints_addons)
- Argo CD AppProject + Application registrados no cluster

**Após rodar:** Argo CD fica em `OutOfSync` (normal, aguarda as imagens).

---

## Etapa 03 — Gateway API (`gateway-api-ci-cd`)

**O que é o Gateway:** É o **ponto de entrada único** da plataforma. Usa YARP (Yet Another Reverse Proxy) para rotear requisições para as APIs internas. Fica no repositório `Fase4-FCG-Orchestrator`.

**Quando rodar:** após o terraform-aws completar e o EKS existir.

**Trigger:**
```
Actions → Orchestrator → gateway-api-ci-cd → Run workflow → branch: master
```

**O que faz:**
1. `dotnet build` do Gateway.Api
2. Auditoria NuGet
3. Push para ECR `gateway-api:<sha>`
4. Push para Docker Hub `fenixdevs/fcg-gateway-api:<sha>` e `:latest`
5. Scan Trivy (SARIF → GitHub Security + gate CRITICAL/HIGH)
6. Atualiza `values-prod.yaml` no próprio Orchestrator → Argo CD faz deploy

---

## Etapa 04 — APIs de negócio (disparar em qualquer ordem)

Cada API tem seu workflow independente. Dispare via `workflow_dispatch`:

### 04a — UsersAPI
```
Actions → Fase4-FCG-UsersAPI → users-api-ci-cd → Run workflow → master
```
- Build + testes integração (PostgreSQL service container)
- Push ECR `users-api` + Docker Hub `fcg-users-api`

### 04b — CatalogAPI
```
Actions → Fase4-FCG-CatalogAPI → catalog-api-ci-cd → Run workflow → master
```
- Build + testes (xUnit + Testcontainers)
- Push ECR `catalog-api` + Docker Hub `fcg-catalog-api`

### 04c — PaymentsAPI
```
Actions → Fase4-FCG-PaymentsAPI → payments-api-ci-cd → Run workflow → master
```
- Build (sem testes — repo não tem projeto de testes)
- Push ECR `payments-api` + Docker Hub `fcg-payments-api`

### 04d — NotificationsAPI
```
Actions → Fase4-FCG-NotificationsAPI → notifications-api-ci-cd → Run workflow → master
```
- Build + testes
- Push ECR `notifications-api` + Docker Hub `fcg-notifications-api`

**Resultado após 04a-04e:** Argo CD detecta as mudanças em `values-prod.yaml` e faz rolling update de cada serviço automaticamente. Todos os pods ficam `Running`.

---

## Etapa 05 — Smoke test (manual)

Após pods estarem `Running`:

```powershell
# Obter DNS do ALB
kubectl -n fcg-platform get ingress

# Rodar smoke test
cd Fase4-FCG-Orchestrator
.\scripts\smoke-test.ps1 -BaseUrl http://<alb-dns>
```

Valida: `/health` do Gateway, listagem de jogos, busca fuzzy, NuGet audit.

---

## Etapa 06 — Destroy (`destroy-aws`)

**Quando rodar:** após gravar o vídeo ou quando quiser parar de pagar.

**Trigger:**
```
Actions → Orchestrator → destroy-aws → Run workflow
```

**Inputs:**
```
confirmation:      DESTRUIR
destroy_bootstrap: false   (mantenha false para poder recriar depois)
```

**Ordem de destruição interna:**
1. Kubernetes → Argo CD App → Ingress → namespace
2. ECR → esvaziar imagens
3. AWS residual → ALBs → NAT Gateways → **Elastic IPs** → ENIs → SGs K8s
4. Terraform destroy → VPC + EKS + RDS + Redis + OpenSearch + DynamoDB + Secrets Manager
5. (opcional) Bootstrap → desanexa IAM Policy → terraform destroy

**Tempo:** ~20-30 min.

---

## Para recriar após destroy

```powershell
# Bootstrap ainda existe (destroy_bootstrap: false):
git commit --allow-empty -m "chore: recreate platform"
git push origin master
# terraform-aws.yml dispara automaticamente → recria tudo em ~25 min
```

---

## Diagrama de dependências

```
bootstrap-aws (01)
      │ (cria IAM role para CI/CD)
      ▼
terraform-aws (02) ──────────────────────────── ~25 min
      │ cria EKS, ECR, RDS, Redis, OpenSearch
      │ renderiza values-prod.yaml com endpoints reais
      │ registra Argo CD no cluster (automático)
      │
      ▼ (qualquer ordem)
gateway-api-ci-cd (03)    users-api-ci-cd (04a)
catalog-api-ci-cd (04b)   payments-api-ci-cd (04c)
notifications-api-ci-cd (04d)
      │ cada um: build → push ECR/DockerHub → atualiza values-prod.yaml
      │ Argo CD detecta mudança → rolling update automático
      │
      ▼
smoke-test.ps1 (05) ──────────────── plataforma funcionando!
      │
      ▼ (quando quiser desligar)
destroy-aws (06) ──────────────────── ~25 min
```

---

## Secrets/Variables por repo (referência rápida)

### Organization secrets (todos os 5 repos)
| Nome | Tipo |
|---|---|
| `AWS_GITHUB_ROLE_ARN` | Secret |
| `DOCKERHUB_USERNAME` | Secret |
| `DOCKERHUB_TOKEN` | Secret |
| `GITOPS_APP_PRIVATE_KEY` | Secret (4 APIs) |

### Organization variables (todos os 5 repos)
| Nome | Tipo |
|---|---|
| `GITOPS_APP_ID` | Variable (4 APIs) |
| `GITOPS_REPOSITORY` | Variable (4 APIs) |

### Repository variables — Orchestrator only
| Nome | Valor |
|---|---|
| `TF_STATE_BUCKET` | `fcg-prod-tfstate-682839842435` |
| `TF_LOCK_TABLE` | `fcg-prod-tfstate-lock` |
| `GITOPS_REPO_URL` | `https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator.git` |

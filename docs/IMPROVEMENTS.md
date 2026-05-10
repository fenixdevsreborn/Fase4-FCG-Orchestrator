# Sugestões de melhoria — Fase 4

Análise comparando a implementação atual com o spec do Tech Challenge (`docs/TC NETT - Fase 4.txt`) e boas práticas de produção. Itens **não obrigatórios pelo spec**, mas que aumentam robustez, observabilidade e custo-benefício.

> Compliance dos itens obrigatórios do spec já validada em [FASE4-COMPLIANCE.md](FASE4-COMPLIANCE.md). Esta lista é complementar.
>
> **Itens implementados** são marcados com ✅. Os demais estão pendentes.

---

## 🔴 Alto impacto / baixo esforço

### ✅ 1. Padronizar nome dos repositórios (FCG vs FGC) — IMPLEMENTADO
- Pastas locais renomeadas: `Fase4-FGC-CatalogAPI` → `Fase4-FCG-CatalogAPI`, `Fase4-FGC-NotificationsAPI` → `Fase4-FCG-NotificationsAPI`
- Renomear também os repositórios remotos no GitHub (Settings → Repository name) se necessário.

### 2. Branch protection rules em `master` (todos os 5 repos)
- **Recomendação:**
  - Require pull request reviews (1+ aprovador)
  - Require status checks (a própria pipeline deve passar antes do merge)
  - GitHub App como bypass actor (não usuário pessoal)
- **Ver:** [SECURITY-SETUP.md §2](SECURITY-SETUP.md)
- **Por quê:** GitOps confia em `master` como fonte da verdade. Push direto sem review pode disparar deploy quebrado.

### ✅ 3. Pinar SHA em GitHub Actions — IMPLEMENTADO
- Todos os workflows agora usam SHAs pinados. Exemplo: `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`
- Renovate/Dependabot pode automatizar a atualização dos SHAs.

### ✅ 4. Cache do `dotnet restore` nas pipelines — IMPLEMENTADO
- `actions/cache@v4.2.2` adicionado em todos os 5 workflows com chave `${{ hashFiles('**/*.csproj', '**/*.slnx') }}`.
- **Ação:** `actions/cache@v4` com chave `${{ hashFiles('**/*.csproj','**/*.slnx') }}`.
- **Ganho:** -1 a -3 minutos por pipeline, -X% no consumo de minutos GHA.

### 5. Habilitar dependency review e secret scanning
- GitHub Settings → Code security → habilitar:
  - **Dependabot alerts + security updates**
  - **Secret scanning** (especialmente para detectar `DOCKERHUB_TOKEN`/`GITOPS_TOKEN` vazados em commits)
  - **Push protection** (bloqueia push de secrets)

---

## 🟠 Médio impacto

### ✅ 5. Habilitar dependency review e secret scanning — IMPLEMENTADO (parcial)
- Secret scanning e push protection: configurar via GitHub Settings → Code security (manual por repo).
- Dependabot: idem.
- Ver [SECURITY-SETUP.md §3](SECURITY-SETUP.md) para o passo a passo.

### ✅ 6. Substituir `GITOPS_TOKEN` (PAT) por GitHub App — IMPLEMENTADO
- Todos os 4 workflows de API agora usam `actions/create-github-app-token@v1.11.3`.
- Secrets alterados: `GITOPS_TOKEN` → `GITOPS_APP_PRIVATE_KEY` (secret) + `GITOPS_APP_ID` (variable).
- Ver [SECURITY-SETUP.md §1](SECURITY-SETUP.md) para criar o GitHub App.

### 7. Promover ambientes (dev → staging → prod)
- **Atual:** existe só `prod`. `terraform apply -var-file=environments/prod.tfvars`.
- **Sugestão:** adicionar `environments/staging.tfvars` com instâncias menores (`db.t4g.small`, OpenSearch `t3.small.search`, RDS sem multi-AZ). Pipeline:
  - Push em `develop` → deploy em staging
  - Tag `vX.Y.Z` em `master` → deploy em prod
- **Custo:** -60% em staging vs prod, valor pedagógico alto.

### ✅ 8. Observabilidade: CloudWatch / Container Insights — IMPLEMENTADO (parcial)
- `enable_aws_for_fluentbit = true` e `enable_aws_cloudwatch_metrics = true` adicionados em `infra/terraform/aws/main.tf`.
- Logs dos containers fluem para CloudWatch log group `/aws/containerinsights/fcg-prod/application`.
- Pendente: AWS X-Ray / OpenTelemetry Collector para tracing distribuído (Gateway → UsersAPI → CatalogAPI → PaymentsAPI).

### 9. cert-manager + Route 53 + ACM
- **Atual:** ALB exposto via DNS gerado pela AWS (ex.: `k8s-fcgplatfo-...elb.amazonaws.com`). Sem HTTPS.
- **Ação:**
  - Provisionar Hosted Zone no Route 53 (`fcg.example.com`)
  - Cert ACM ou cert-manager com Let's Encrypt
  - Anotação `alb.ingress.kubernetes.io/certificate-arn` no Ingress
- **Spec menciona "exposição via Load Balancer/Ingress"** — funciona, mas HTTPS fica feio sem certificado.

### 10. HA do RabbitMQ (AWS MQ)
- **Atual:** `deployment_mode = SINGLE_INSTANCE_BROKER` em `aws_mq_broker.rabbitmq`.
- **Risco:** broker indisponível = todo evento async parado.
- **Ação:** trocar para `CLUSTER_MULTI_AZ`. Custa ~3× mais ($), mas elimina SPOF.

### 11. Snapshot final dos RDS / DynamoDB Point-in-Time Recovery
- **Atual:** RDS provavelmente com `skip_final_snapshot = true`.
- **Ação:** ajustar para `false` em prod e habilitar `point_in_time_recovery_enabled = true` no DynamoDB.

---

## 🟡 Refinamentos

### 12. SBOM + assinatura de imagem (cosign)
- **Por quê:** auditoria de supply chain. Trivy já scaneia CVEs, mas não gera SBOM nem assina.
- **Ação:** adicionar steps `anchore/sbom-action` (gera SPDX) e `sigstore/cosign-installer` + `cosign sign` após push ECR/Docker Hub.
- **Bônus:** Argo CD pode validar assinatura antes do deploy via Kyverno/OPA.

### 13. Centralizar build args + matriz de pipelines
- **Atual:** cada pipeline `.yml` é uma cópia quase idêntica. Manter 5 cópias é ruim.
- **Ação:** extrair um **reusable workflow** em `.github/workflows/_dotnet-ecr-dockerhub.yml` com inputs (`service-name`, `dockerfile-path`, `solution-file`, `dockerhub-repo`, `ecr-repo`). Cada repo usa `uses: <org>/Fase4-FCG-Orchestrator/.github/workflows/_dotnet-ecr-dockerhub.yml@master`.
- **Ganho:** -200 linhas por repo, mudanças só num lugar.

### ✅ 14. Healthchecks customizados nos containers — IMPLEMENTADO
- `HEALTHCHECK` instruction adicionada nos 5 Dockerfiles.
- Comando: `curl -f http://localhost:8080/health || exit 1` com interval 30s, timeout 10s, start-period 60s.

### ✅ 15. Trivy: gerar relatório SARIF e enviar para GitHub Security — IMPLEMENTADO
- Todos os 5 workflows agora rodam Trivy duas vezes: uma para SARIF (upload para aba Security), outra para gate (falha em CRITICAL/HIGH).
- Usa `github/codeql-action/upload-sarif@v3.28.18` com `if: always()`.

### ✅ 16. Validar Helm chart (`helm lint` + `helm template`) na pipeline do Orchestrator — IMPLEMENTADO
- Job `validate` adicionado no `terraform-aws.yml`, executa antes do `plan`.
- Usa `azure/setup-helm@v4.3.0` + `helm lint` + `helm template`.

### 17. Cache no GitHub Actions para Docker layers
- Usar `docker/build-push-action@v6` com `cache-from/cache-to: type=gha` em vez de `docker build` puro.
- Rebuilds que mudam só código compilado caem para ~30s.

### ✅ 18. Documentar RTO/RPO e disaster recovery — IMPLEMENTADO
- Ver [DISASTER-RECOVERY.md](DISASTER-RECOVERY.md) — inclui rollback ArgoCD/GitOps, restore RDS, reconstrução de cluster, tabela RTO/RPO.

---

## 🟢 Limpeza / dívida técnica

### ✅ 19. Remover docs da Fase 2 que não se aplicam mais — IMPLEMENTADO
- READMEs atualizados: "Fase 2" trocado por "Fase 4" em todos os 5 repos.

### 20. Remover docker-compose.yml dos repos individuais ou consolidar no Orchestrator
- Cada API tem seu `docker-compose.yml` standalone, mas o `Fase4-FCG-Orchestrator/docker-compose.yml` já cobre o ambiente local completo.
- **Ação:** marcá-lo como "compose isolado para testar a API sem o resto da stack" ou removê-lo.

### ✅ 21. Padronizar nomes de variáveis de ambiente — IMPLEMENTADO (documentado)
- Ver [ENV-VARS.md](ENV-VARS.md) — tabela completa de variáveis, padrão escolhido (`RabbitMQ__Host`) e ação necessária para migrar NotificationsAPI.

### ✅ 22. CHANGELOG e versionamento semântico de imagem — IMPLEMENTADO
- Workflow `release.yml` criado usando `googleapis/release-please-action@v4.1.3`.
- A cada push em `master`, o release-please abre PR de release seguindo Conventional Commits.
- Quando o PR é mergeado, cria tag `vX.Y.Z` e GitHub Release automaticamente.

---

## Resumo prioritizado

| Prioridade | Item | Status | Esforço |
|---|---|---|---|
| 🔥 P0 | Padronizar FCG/FGC (1) | ✅ Implementado | — |
| 🔥 P0 | Branch protection em `master` (2) | Pendente | 10 min por repo |
| ✅ P1 | GitHub App (6) | ✅ Implementado | — |
| ✅ P1 | SHAs pinados (3) | ✅ Implementado | — |
| ✅ P1 | Cache NuGet (4) | ✅ Implementado | — |
| ✅ P1 | HEALTHCHECK Dockerfiles (14) | ✅ Implementado | — |
| ✅ P1 | Trivy SARIF (15) | ✅ Implementado | — |
| ✅ P1 | Helm lint (16) | ✅ Implementado | — |
| ✅ P1 | Container Insights (8) | ✅ Implementado | — |
| ✅ P1 | DISASTER-RECOVERY.md (18) | ✅ Implementado | — |
| ✅ P1 | ENV-VARS.md (21) | ✅ Implementado | — |
| ✅ P1 | Release semântico (22) | ✅ Implementado | — |
| ⚡ P2 | HA RabbitMQ (10) | Pendente | 30 min config |
| ⚡ P2 | Reusable workflow (13) | Pendente | 2h |
| 🌱 P3 | Observabilidade X-Ray | Pendente | 1 dia |
| 🌱 P3 | cert-manager + Route 53 (9) | Pendente | 4h |
| 💎 P4 | SBOM + cosign (12) | Pendente | 4h |
| 💎 P4 | Cache Docker layers (17) | Pendente | 1h |

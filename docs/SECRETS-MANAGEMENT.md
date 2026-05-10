# Gestão de Secrets — Análise e Melhores Práticas

> **Sequência de setup** → [1. Bootstrap](BOOTSTRAP.md) → [2. GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) → **Você está aqui: [3. Secrets]** → [4. Configurar secrets](MANUAL-STEPS.md#4-configurar-github-secretsvariables) → [5. Deploy inicial](MANUAL-STEPS.md#6-push-em-master-do-orchestrator-a-partir-daqui-é-automático)

---

Este documento responde à pergunta: "Preciso colocar secrets manualmente no GitHub? Posso usar Cloudflare ou outro serviço externo para evitar isso?"

---

## TL;DR — Recomendação para este projeto

| Situação | Solução recomendada |
|---|---|
| Repos em organização GitHub | **GitHub Organization Secrets** (zero config por repo, gratuito, nativo) |
| Repos em conta pessoal | **Doppler** (sincronização automática, free tier) |
| AWS credentials em CI | **OIDC** (já implementado — sem credenciais estáticas) |
| Secrets de app em produção | **AWS Secrets Manager** (já implementado via Terraform) |
| Bootstrap (única vez) | Credenciais estáticas temporárias + workflow `bootstrap.yml` |

---

## Por que Cloudflare NÃO é a solução

Cloudflare é excelente para CDN, DDoS, DNS e tunnels — mas **não possui um serviço de gestão de secrets** para o caso de uso desta plataforma.

| Produto Cloudflare | O que faz | Aplica a este projeto? |
|---|---|---|
| **Workers Secrets** | Secrets exclusivos para Cloudflare Workers | Não — só funciona dentro de Workers CF |
| **Zero Trust / Access** | Proxy e autenticação para apps internas | Não — é controle de acesso, não secrets |
| **R2 / KV / D1** | Storage de dados | Não — não é gestão de secrets |
| **Cloudflare Gateway** | Filtro DNS/HTTP | Não — é firewall de rede |

**Conclusão:** Não existe um produto Cloudflare que substitua AWS Secrets Manager, GitHub Secrets, ou Doppler para injetar credenciais em pipelines CI/CD. Cloudflare não se integra ao GitHub Actions da forma que o projeto precisa.

---

## Opção 1: GitHub Organization Secrets (recomendada, gratuita)

**O que é:** Secrets configurados em nível de organização GitHub, compartilhados automaticamente com todos os repositórios selecionados — sem configurar nada por repo.

**Por que é a melhor para este projeto:**
- Já está disponível no plano gratuito do GitHub
- Zero dependência externa
- Adicionar um novo repo ao projeto = acesso automático aos secrets
- Auditoria integrada (GitHub audit log)

### Como configurar (uma vez, para todos os repos)

> URL direta: `https://github.com/organizations/<sua-org>/settings/secrets/actions`

1. Acesse a URL acima (substitua `<sua-org>`)
2. Em **Organization secrets**, clique em **New organization secret**
3. Configure o acesso: **Selected repositories** → selecione os 5 repos FCG
4. Adicione cada secret abaixo

**Secrets de organização a criar:**

| Nome | Valor | Repos com acesso |
|---|---|---|
| `AWS_GITHUB_ROLE_ARN` | ARN output do bootstrap | Todos os 5 |
| `DOCKERHUB_USERNAME` | Seu username Docker Hub | Todos os 5 |
| `DOCKERHUB_TOKEN` | PAT Docker Hub Read & Write | Todos os 5 |
| `GITOPS_APP_PRIVATE_KEY` | Conteúdo do .pem do GitHub App | 4 APIs (não Orchestrator) |

**Variables de organização a criar:**

| Nome | Valor | Repos com acesso |
|---|---|---|
| `GITOPS_APP_ID` | ID do GitHub App FCG GitOps | 4 APIs |

**Secrets específicos do Orchestrator** (ainda precisam ser por repo):

| Nome | Valor |
|---|---|
| `TF_STATE_BUCKET` | Variable — output do bootstrap |
| `TF_LOCK_TABLE` | Variable — output do bootstrap |
| `GITOPS_REPO_URL` | Variable — `https://github.com/<org>/Fase4-FCG-Orchestrator.git` |

**Resultado:** Com os secrets de organização, cada novo repo FCG adicionado receberá automaticamente as credenciais sem nenhuma configuração adicional. Os únicos secrets que precisam de configuração por repo são os 3 do Orchestrator acima.

### Limitação
- Funciona somente se os repos estiverem em uma **organização GitHub**, não em conta pessoal.
- Para conta pessoal: use Doppler (próxima seção).

> **Feito com GitHub Org Secrets? →** [Ir para MANUAL-STEPS.md §4 — Configurar secrets](MANUAL-STEPS.md#4-configurar-github-secretsvariables)
> (apenas os 3 itens específicos do Orchestrator que não são org-level)

---

## Opção 2: Doppler (secrets manager SaaS)

**O que é:** SaaS que armazena todos os secrets em um lugar, com sincronização automática para GitHub, AWS Secrets Manager, Vercel, Heroku e outros.

**Quando usar:** Quando os repos estão em conta pessoal, ou quando você quer um painel único para ver e rotar todos os secrets sem entrar no GitHub UI.

### Como funciona com GitHub Actions

O Doppler tem dois modos de integração com GitHub:

**Modo A — Sync automático (recomendado):** O Doppler sincroniza os secrets diretamente nos GitHub Secrets do repositório. Toda vez que um secret muda no Doppler, ele é atualizado automaticamente no GitHub. Seus workflows continuam usando `${{ secrets.NOME }}` normalmente — sem nenhuma mudança nos YMLs.

**Modo B — Injeção em runtime:** O workflow usa `doppler run --` ou a action `dopplerhq/cli-action` para buscar secrets do Doppler em tempo de execução. Requer um `DOPPLER_TOKEN` no GitHub como único secret manual.

### Setup do Doppler (Modo A — Sync)

```
1. Criar conta em doppler.com (free tier inclui 5 projetos, secrets ilimitados)
2. Criar projeto: "fcg-platform"
3. Criar ambiente: "prod"
4. Adicionar todos os secrets ao Doppler:
   - AWS_GITHUB_ROLE_ARN
   - DOCKERHUB_USERNAME / DOCKERHUB_TOKEN
   - GITOPS_APP_ID / GITOPS_APP_PRIVATE_KEY
   - TF_STATE_BUCKET / TF_LOCK_TABLE / GITOPS_REPO_URL
5. Integrações → GitHub → Selecionar repositório → Selecionar ambiente
6. Doppler sincroniza automaticamente para GitHub Secrets
7. Toda vez que você muda um secret no Doppler, o GitHub é atualizado em segundos
```

### Vantagens
- Histórico de mudanças com quem alterou e quando
- Rotação de secrets com um clique (Doppler atualiza GitHub e AWS ao mesmo tempo)
- Interface web clara para ver todos os secrets da plataforma
- Free tier cobre este projeto inteiro

### Desvantagem
- Dependência de serviço terceiro (se Doppler cair, secrets não são atualizados — mas os existentes no GitHub continuam funcionando)
- Requer setup manual inicial no Doppler UI

### Integração Doppler + AWS Secrets Manager

O Doppler pode sincronizar secrets TAMBÉM para o AWS Secrets Manager, em paralelo ao GitHub. Isso seria útil se você quisesse usar o Doppler como fonte única da verdade para todo o ecossistema — mas para este projeto, o AWS Secrets Manager já é populado pelo Terraform, então não há necessidade.

---

## Opção 3: Infisical (open-source, auto-hospedável)

**O que é:** Alternativa open-source ao Doppler. Pode ser auto-hospedado (Docker/Kubernetes) ou usado como SaaS (infisical.com).

### Quando usar
- Se você prefere não depender de SaaS de terceiros para secrets
- Se já tem infraestrutura para hospedar (um pod no EKS FCG, por exemplo)
- Se compliance exige que secrets nunca saiam da sua infraestrutura

### Integração com GitHub e AWS

Infisical tem a [GitHub Actions integration](https://infisical.com/docs/integrations/cicd/githubactions) e [AWS Secrets Manager sync](https://infisical.com/docs/integrations/cloud/aws-secret-manager), funcionando de forma similar ao Doppler.

### Limitação
- A versão auto-hospedada requer manutenção do servidor Infisical
- O SaaS Infisical tem free tier mais limitado que o Doppler

---

## Opção 4: HashiCorp Vault

**O que é:** Solução enterprise de gestão de secrets, self-hosted ou SaaS (HCP Vault).

**Quando usar:** Projetos enterprise com requisitos de compliance rigorosos (SOC 2, PCI-DSS, HIPAA).

**Para este projeto:** Overkill. A complexidade de setup supera o benefício. GitHub Organization Secrets ou Doppler são mais adequados.

---

## Comparação final

| | GitHub Org Secrets | Doppler | Infisical | Cloudflare | Vault |
|---|:---:|:---:|:---:|:---:|:---:|
| Funciona com GitHub Actions | ✅ | ✅ | ✅ | ❌ | ✅ |
| Funciona com AWS ECR/SM | via OIDC | ✅ (sync) | ✅ (sync) | ❌ | ✅ |
| Custo | Gratuito | Free tier | Free/self-host | N/A | Pago |
| Requer configuração por repo | Não | Não | Não | — | Não |
| Dependência externa | Não | Sim | Opcional | — | Sim |
| Auditoria | GitHub log | Dashboard | Dashboard | — | Dashboard |
| Rotação automática | Manual | Um clique | Um clique | — | Automática |
| Ideal para | Orgs GitHub | Conta pessoal / multi-env | Compliance rigoroso | ❌ | Enterprise |

---

## Arquitetura de secrets deste projeto

```
                    ┌─────────────────────────┐
                    │   Fonte da Verdade       │
                    │   (GitHub Org Secrets   │
                    │    ou Doppler)           │
                    └──────────┬──────────────┘
                               │ auto-sync (Doppler)
                               │ ou nativo (Org Secrets)
               ┌───────────────┴───────────────┐
               │                               │
    ┌──────────▼──────────┐        ┌──────────▼──────────┐
    │  GitHub Actions      │        │  AWS Secrets Manager │
    │  Secrets/Variables   │        │  (via Terraform +    │
    │  (CI/CD pipeline)    │        │   External Secrets)  │
    └──────────┬──────────┘        └──────────┬──────────┘
               │                               │
    ┌──────────▼──────────┐        ┌──────────▼──────────┐
    │  Pipeline roda       │        │  Pods EKS recebem   │
    │  build/push/deploy   │        │  secrets em runtime  │
    └─────────────────────┘        └─────────────────────┘
```

**Credenciais AWS na pipeline:** Zero — OIDC elimina chaves estáticas. A pipeline assume a IAM Role via token JWT de curta duração.

**Credenciais de app em produção:** Zero no código — External Secrets Operator busca do Secrets Manager e injeta como env vars nos pods.

---

## Secrets que ainda precisam ser configurados manualmente (mínimo irredutível)

Independente de qual opção você escolher, alguns secrets só podem ser criados manualmente por natureza:

| Secret | Por quê é manual | Frequência |
|---|---|---|
| `BOOTSTRAP_AWS_ACCESS_KEY_ID` + `BOOTSTRAP_AWS_SECRET_ACCESS_KEY` | Necessário para o bootstrap inicial. **Excluir após uso.** | Uma vez |
| `DOCKERHUB_TOKEN` | Docker Hub não suporta OIDC. Precisa de PAT. | A cada 90 dias (rotação) |
| `GITOPS_APP_PRIVATE_KEY` | Private key do GitHub App. Gerada manualmente no GitHub. | A cada 1 ano |
| `GH_ADMIN_PAT` (opcional) | Usado pelo bootstrap.yml para auto-configurar secrets. **Excluir após uso.** | Uma vez |

Com GitHub Organization Secrets + OIDC, o número de secrets que você gerencia manualmente cai de **~25 configurações** (5 repos × 5 secrets cada) para **4-6 itens**.

---

## Roteiro de implementação recomendado

### Para organização GitHub (recomendado)

```
1. Executar bootstrap.yml workflow (uma vez)
   → Cria OIDC + IAM role + S3 + DynamoDB
   → Exibe outputs nos logs

2. Configurar GitHub Organization Secrets (uma vez)
   → AWS_GITHUB_ROLE_ARN (org secret → 5 repos)
   → DOCKERHUB_USERNAME + DOCKERHUB_TOKEN (org secret → 5 repos)
   → GITOPS_APP_PRIVATE_KEY + GITOPS_APP_ID (org secret → 4 APIs)

3. Configurar secrets específicos do Orchestrator (uma vez)
   → TF_STATE_BUCKET, TF_LOCK_TABLE, GITOPS_REPO_URL (repo variables)

4. Excluir credenciais bootstrap
   → Desativar/excluir BOOTSTRAP_AWS_ACCESS_KEY_ID da AWS
   → Remover do GitHub Secrets

5. Resultado final:
   → Zero credenciais AWS estáticas no GitHub
   → Zero configuração de secrets ao adicionar novos repos
   → OIDC para AWS, GitHub App para GitOps, PAT mínimo para Docker Hub
```

### Para conta pessoal GitHub (com Doppler)

```
1. Criar conta Doppler + projeto "fcg-platform"
2. Adicionar todos os secrets ao Doppler
3. Configurar integração Doppler → GitHub (por repo)
4. Executar bootstrap.yml workflow
5. Excluir credenciais bootstrap
```

---

## Referências

- [BOOTSTRAP.md](BOOTSTRAP.md) — como executar o bootstrap (local ou via GitHub Actions)
- [SECURITY-SETUP.md](SECURITY-SETUP.md) — GitHub App, branch protection, rotação de credenciais
- [MANUAL-STEPS.md](MANUAL-STEPS.md) — checklist completo de setup
- [Doppler docs](https://docs.doppler.com) — integração com GitHub Actions
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [GitHub Organization Secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-an-organization)

---

> **Navegação:**
> ← [2. GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) | **Você está aqui: Secrets** | [4. Configurar secrets →](MANUAL-STEPS.md#4-configurar-github-secretsvariables)

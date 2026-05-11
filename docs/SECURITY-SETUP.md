# Configuração de Segurança

> **Sequência de setup** → [1. Bootstrap](BOOTSTRAP.md) → **Você está aqui: [2. GitHub App + Segurança]** → [3. Secrets](SECRETS-MANAGEMENT.md) → [4. Configurar secrets](MANUAL-STEPS.md#4-configurar-github-secretsvariables) → [5. Deploy inicial](MANUAL-STEPS.md#6-push-em-master-do-orchestrator-a-partir-daqui-é-automático)

---

## 1. GitHub App para GitOps (substitui PAT)

As pipelines das APIs precisam fazer push no repositório `Fase4-FCG-Orchestrator` para atualizar `values-prod.yaml`. Isso exige um token com permissão de escrita.

**Por que GitHub App e não PAT:**
- PAT é vinculado a um usuário pessoal; se o usuário sair, todas as 4 pipelines quebram
- PAT tem escopo amplo e não expira automaticamente
- GitHub App é uma identidade de machine, com token de 1 hora, instalável só no repo necessário

---

### 1.1 Criar o GitHub App

> **URLs diretas** — substitua `<sua-org>` pelo nome da sua organização ou usuário:
>
> - Organização: `https://github.com/organizations/<sua-org>/settings/apps/new`
> - Conta pessoal: `https://github.com/settings/apps/new`

**Passo a passo:**

1. Acesse a URL acima (substitua `<sua-org>`)
2. Preencha o formulário:

   | Campo | Valor |
   |---|---|
   | **GitHub App name** | `FCG GitOps` |
   | **Homepage URL** | `https://github.com/<sua-org>` |
   | **Webhook → Active** | **Desmarque** esta opção |

3. Em **Repository permissions**, configure:

   | Permissão | Nível |
   |---|---|
   | **Contents** | **Read and write** |
   | **Metadata** | Read-only (marcado automaticamente) |

4. Em **Where can this GitHub App be installed?** → selecione **Only on this account**
5. Clique em **Create GitHub App**

Você será redirecionado para a página do App. Na parte superior você verá:
```
App ID: 123456
```
**Anote este número** — é o valor de `GITOPS_APP_ID`.

---

### 1.2 Gerar a private key

Ainda na página do GitHub App (URL: `https://github.com/settings/apps/FCG-GitOps` ou `https://github.com/organizations/<sua-org>/settings/apps/FCG-GitOps`):

1. Role a página até a seção **Private keys**
2. Clique em **Generate a private key**
3. O arquivo `fcg-gitops.<timestamp>.private-key.pem` é baixado automaticamente
4. Guarde este arquivo em local seguro — é como uma senha, não pode ser recuperado
5. Abra o arquivo com qualquer editor de texto. O conteúdo tem este formato:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4b3ggNmE8YBLr5kzn...
[várias linhas de caracteres base64]
-----END RSA PRIVATE KEY-----
```

**Todo este conteúdo** (incluindo as linhas BEGIN e END) é o valor do secret `GITOPS_APP_PRIVATE_KEY`.

---

### 1.3 Instalar o App no repositório Orchestrator

> URL direta: `https://github.com/settings/apps/FCG-GitOps/installations`
> (ou para org: `https://github.com/organizations/<sua-org>/settings/apps/FCG-GitOps/installations`)

1. Clique em **Install App**
2. Selecione sua conta ou organização
3. Escolha **Only select repositories**
4. Selecione apenas `Fase4-FCG-Orchestrator` (somente este — não os outros)
5. Clique em **Install**

Confirmação: você verá "Installed on X repositories".

---

### 1.4 Configurar nos 4 repositórios de API

Para **cada um** dos 4 repos de API (`Fase4-FCG-UsersAPI`, `Fase4-FCG-CatalogAPI`, `Fase4-FCG-PaymentsAPI`, `Fase4-FCG-NotificationsAPI`):

> URL direta do repo: `https://github.com/<sua-org>/<repo>/settings/secrets/actions`

**Adicionar Variable `GITOPS_APP_ID`:**
- Settings → Secrets and variables → Actions → aba **Variables** → **New repository variable**
- Name: `GITOPS_APP_ID`
- Value: número do App (ex: `123456`)

**Adicionar Secret `GITOPS_APP_PRIVATE_KEY`:**
- Settings → Secrets and variables → Actions → aba **Secrets** → **New repository secret**
- Name: `GITOPS_APP_PRIVATE_KEY`
- Value: cole o conteúdo completo do arquivo `.pem`

> **Alternativa mais rápida — GitHub Organization Secrets:**
> Se os repos estiverem em uma organização, configure uma vez e todos os repos recebem automaticamente.
> Ver [SECRETS-MANAGEMENT.md → Opção 1](SECRETS-MANAGEMENT.md#opção-1-github-organization-secrets-recomendada-gratuita).

> O secret `GITOPS_TOKEN` (PAT antigo) pode ser removido após confirmar que as pipelines funcionam com o GitHub App.

---

> **Próxima etapa →** Decidir estratégia de gestão de secrets (GitHub Org Secrets vs Doppler).
> [Ir para SECRETS-MANAGEMENT.md →](SECRETS-MANAGEMENT.md)

---

## 2. Branch protection em `master`

Configure em **cada um** dos 5 repositórios.

> URL direta: `https://github.com/<sua-org>/<repo>/settings/branches`

1. Clique em **Add branch protection rule** (ou **Add ruleset** no novo UI)
2. **Branch name pattern:** `master`
3. Configure:

| Configuração | Valor |
|---|---|
| Require a pull request before merging | Ativado — 1 required approving review |
| Require status checks to pass | Ativado — nome do check: `build-test-push-deploy` |
| Require branches to be up to date before merging | Ativado |
| Restrict who can push to matching branches | Ativado |
| Allow specified actors to bypass required pull requests | Adicionar **GitHub App `FCG GitOps`** |

> **Por que o bypass?** O GitHub App precisa fazer push direto em `master` para commitar `values-prod.yaml` no Orchestrator durante deploys de CI. Sem bypass, o deploy automático fica bloqueado.

---

## 3. GitHub Security features

Configure em **cada repositório**.

> URL direta: `https://github.com/<sua-org>/<repo>/settings/security_analysis`

| Feature | Ação | Benefício |
|---|---|---|
| **Dependabot alerts** | Enable | Notifica sobre CVEs em dependências NuGet |
| **Dependabot security updates** | Enable | Abre PRs automáticos com fixes |
| **Secret scanning** | Enable | Detecta tokens/chaves no código |
| **Push protection** | Enable | Bloqueia push antes que secrets entrem no histórico |
| **Code scanning (CodeQL)** | Enable via Actions | Detecta vulnerabilidades no código C# |

**Ativar Code Scanning:**
1. Aba **Security** do repo → **Enable code scanning** → **Set up this workflow** → selecione CodeQL
2. GitHub cria automaticamente `.github/workflows/codeql.yml`

**Verificar:** Security tab → Overview — deve mostrar as features ativas.

---

## 4. Rotação de credenciais

| Credencial | Localização | Como rotacionar | Frequência |
|---|---|---|---|
| `DOCKERHUB_TOKEN` | GitHub Secret (5 repos) | Docker Hub → Account Settings → Security → revogar antigo → criar novo → atualizar secrets | 90 dias |
| `GITOPS_APP_PRIVATE_KEY` | GitHub Secret (4 APIs) | GitHub App → Private keys → Generate → revogar antiga → atualizar secrets | 1 ano |
| Senhas RDS / Redis / RabbitMQ / OpenSearch | AWS Secrets Manager (Terraform) | `terraform apply` com `random_password` regenerado | 6 meses |
| `AWS_GITHUB_ROLE_ARN` | GitHub Secret | Não é credencial — é ARN de role. Não rotacionar | — |

---

## 5. O que o Terraform já faz (sem config manual)

| Item | Como implementado |
|---|---|
| Zero credenciais hardcoded | Senhas geradas por `random_password`, salvas no Secrets Manager |
| Injeção de secrets nos pods | External Secrets Operator + `ExternalSecret` no Helm chart |
| IRSA para CatalogAPI | IAM Role for Service Account — acessa DynamoDB sem chave estática |
| Scan de vulnerabilidades | Trivy em todos os 5 workflows (CRITICAL/HIGH bloqueiam deploy) |
| Auditoria NuGet | `dotnet list package --vulnerable` em todos os workflows |
| Security group restritivo | Dados acessíveis somente dentro do VPC |

---

> **Navegação:**
> ← [1. Bootstrap](BOOTSTRAP.md) | **Você está aqui: Segurança** | [3. Secrets →](SECRETS-MANAGEMENT.md)

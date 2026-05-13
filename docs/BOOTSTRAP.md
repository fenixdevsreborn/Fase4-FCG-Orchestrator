# Bootstrap AWS — Guia Completo

> **Sequência de setup** → Você está aqui: **[1. Bootstrap]** → [2. GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) → [3. Secrets](SECRETS-MANAGEMENT.md) → [4. Configurar secrets](MANUAL-STEPS.md#4-configurar-github-secretsvariables) → [5. Deploy inicial](MANUAL-STEPS.md#6-push-em-master-do-orchestrator-a-partir-daqui-é-automático)

---

O bootstrap cria os pré-requisitos para toda a automação da plataforma FCG:

| Recurso criado | Para que serve |
|---|---|
| **Provedor OIDC** no IAM | Confia nos tokens JWT emitidos pelo GitHub Actions |
| **IAM Role `fcg-prod-github-actions`** | Assumida pelas pipelines — sem credenciais estáticas |
| **S3 Bucket** | State remoto do Terraform principal (`infra/terraform/aws`) |
| **DynamoDB Table** | Lock do Terraform (evita dois applies simultâneos) |

> **Chicken-and-egg:** o bootstrap usa credenciais estáticas temporárias para criar o provedor OIDC que elimina a necessidade de credenciais estáticas. Após o bootstrap, delete as chaves temporárias — tudo usa OIDC.

---

## Pré-requisitos (para ambos os caminhos)

### 1. Usuário IAM `fcg-bootstrap-admin`

Você já criou este usuário com `AdministratorAccess`. Agora precisa criar uma **Access Key** para ele.

**Na tela "Criar chave de acesso" que você vê:**
- Selecione **"Outros"** (caso de uso mais adequado para CI/CD externo)
- Clique em **Próximo** → adicione uma descrição opcional → **Criar chave de acesso**
- **Copie o Access Key ID e o Secret Access Key** — você os verá uma única vez

### 2. Repositório GitHub `Fase4-FCG-Orchestrator`

O workflow `bootstrap.yml` já existe neste repositório. Certifique-se que o repo está criado com branch `master`.

---

## Caminho A — Bootstrap via GitHub Actions (recomendado)

Não requer instalar nenhum software localmente. O Terraform roda na infraestrutura do GitHub.

### Passo 1 — Configurar secrets temporários no GitHub

No repositório `Fase4-FCG-Orchestrator`: **Settings → Secrets and variables → Actions → New repository secret**

| Nome | Valor |
|---|---|
| `BOOTSTRAP_AWS_ACCESS_KEY_ID` | Access Key ID do `fcg-bootstrap-admin` |
| `BOOTSTRAP_AWS_SECRET_ACCESS_KEY` | Secret Access Key do `fcg-bootstrap-admin` |

> O bootstrap não configura secrets de outros repositórios automaticamente. Ele só cria os recursos AWS e exibe os outputs para configuração manual.

### Passo 2 — Criar o environment `bootstrap` (recomendado)

Para proteger o workflow de execuções acidentais:

**Settings → Environments → New environment → Nome: `bootstrap`**

Configure **Required reviewers**: adicione você mesmo. Desta forma, o workflow só roda após aprovação manual.

### Passo 3 — Disparar o workflow

**Actions → bootstrap-aws → Run workflow**

Preencha os inputs:
- **github_org:** nome da sua organização GitHub (ex: `thefenixdevs`)

Clique em **Run workflow** → aprove no environment `bootstrap` (se configurado).

O workflow irá:
1. Configurar credenciais AWS temporárias
2. Executar `terraform init` + `terraform apply` no `infra/terraform/bootstrap/`
3. Capturar e exibir os outputs nos logs
4. Exibir instruções para configuração manual dos secrets/variables
5. Exibir instruções de limpeza

### Passo 4 — Anotar os outputs

Nos logs do workflow, você verá:
```
============================================================
BOOTSTRAP CONCLUÍDO — ANOTE ESTES VALORES:
============================================================
AWS_GITHUB_ROLE_ARN = arn:aws:iam::682839842435:role/fcg-prod-github-actions
TF_STATE_BUCKET     = fcg-prod-tfstate-682839842435
TF_LOCK_TABLE       = fcg-prod-tfstate-lock
OIDC_PROVIDER_ARN   = arn:aws:iam::682839842435:oidc-provider/token.actions.githubusercontent.com
============================================================
```

### Passo 5 — Configurar secrets nos repos

Siga o roteiro em [MANUAL-STEPS.md §4](MANUAL-STEPS.md) com os valores do passo 4.

**Alternativa — GitHub Organization Secrets (mais elegante):**
Se os repos estão em uma organização GitHub, configure os secrets apenas uma vez em nível de organização. Ver [SECRETS-MANAGEMENT.md §Opção 1](SECRETS-MANAGEMENT.md).

### Passo 6 — Excluir credenciais de bootstrap (OBRIGATÓRIO)

```
1. GitHub: Settings → Secrets → excluir BOOTSTRAP_AWS_ACCESS_KEY_ID
2. GitHub: Settings → Secrets → excluir BOOTSTRAP_AWS_SECRET_ACCESS_KEY
3. AWS Console: IAM → Users → fcg-bootstrap-admin → Security credentials
   → Deactivate (ou Delete) a Access Key
```

Após esta limpeza: **zero credenciais estáticas AWS no GitHub**. Tudo usa OIDC.

> Se algum dia você executar `destroy-aws` com `destroy_bootstrap: true`, gere uma nova access key
> temporária para o `fcg-bootstrap-admin` e recrie os secrets `BOOTSTRAP_AWS_ACCESS_KEY_ID` e
> `BOOTSTRAP_AWS_SECRET_ACCESS_KEY` no repositório Orchestrator ou no environment `prod` antes do workflow.
> Exclua a chave novamente ao final.

---

> **Próxima etapa obrigatória →** Criar o **GitHub App `FCG GitOps`** antes de configurar os secrets das APIs.
> [Ir para SECURITY-SETUP.md — Seção 1: GitHub App](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat)

---

## Caminho B — Bootstrap local (alternativo)

Se preferir rodar localmente, você precisa de AWS CLI e Terraform instalados.

### Pré-requisitos locais

**AWS CLI:**
```powershell
winget install Amazon.AWSCLI
aws --version  # aws-cli/2.x.x

# Configurar com as credenciais do fcg-bootstrap-admin
aws configure
# AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name: us-east-1
# Default output format: json

# Verificar
aws sts get-caller-identity
```

**Terraform:**
```powershell
winget install HashiCorp.Terraform
terraform -version  # Terraform v1.x.x
```

### Executar o bootstrap

```powershell
cd e:\02-Projects\019-FIAP\FASE4\Fase4-FCG-Orchestrator\infra\terraform\bootstrap
Copy-Item environments\prod.tfvars.example environments\prod.tfvars

# Editar environments\prod.tfvars: altere github_org="<sua-org>"
# Os github_repos já vêm com os nomes Fase4-FCG-* corretos

terraform init
terraform apply -var-file=environments/prod.tfvars
# Digitar "yes" quando solicitado
```

### Capturar outputs

```powershell
$ROLE   = terraform output -raw github_actions_role_arn
$BUCKET = terraform output -raw tfstate_bucket
$LOCK   = terraform output -raw tfstate_lock_table
Write-Output "AWS_GITHUB_ROLE_ARN = $ROLE"
Write-Output "TF_STATE_BUCKET     = $BUCKET"
Write-Output "TF_LOCK_TABLE       = $LOCK"
```

> **Não commite `terraform.tfstate`** — adicione ao `.gitignore`.

---

## Verificar se o bootstrap foi bem-sucedido

Após executar (qualquer caminho):

```powershell
# Verificar OIDC provider
aws iam list-open-id-connect-providers

# Verificar IAM role
aws iam get-role --role-name fcg-prod-github-actions

# Verificar S3 bucket
aws s3 ls | Select-String "fcg-prod-tfstate"

# Verificar DynamoDB
aws dynamodb describe-table --table-name fcg-prod-tfstate-lock
```

---

## Erros comuns

| Erro | Causa | Solução |
|---|---|---|
| `no valid credential sources found` | Credenciais não configuradas | AWS CLI: `aws configure` / GitHub: verificar secrets |
| `BucketAlreadyExists` | S3 bucket já existe com esse nome | Adicionar `state_bucket_name = "outro-nome"` no tfvars |
| `EntityAlreadyExists: OpenIDConnectProvider` | OIDC já criado (apply anterior) | Normal — Terraform reaproveita |
| `AccessDeniedException` | Permissão insuficiente | Verificar `AdministratorAccess` no usuário |
| `InvalidClientTokenId` | Access Key inválida/expirada | Gerar nova Access Key no IAM Console |
| Workflow não dispara | Branch padrão não é `master` | Settings → Default branch → `master` |
| `The argument to github_org must be non-empty` | Input `github_org` vazio no workflow | Preencher o input ao disparar |

---

## Re-executar o bootstrap

`terraform apply` é idempotente — pode rodar novamente sem efeitos colaterais:
- Adicionar novo repo em `github_repos`
- Rotacionar thumbprint OIDC
- Recriar recursos excluídos acidentalmente

---

## Próximos passos — em ordem

| Etapa | O que fazer | Documento |
|---|---|---|
| **→ Agora** | Criar o GitHub App `FCG GitOps` + baixar `.pem` | [SECURITY-SETUP.md §1](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat) |
| Depois | Decidir estratégia de secrets (GitHub Org ou Doppler) | [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md) |
| Depois | Configurar secrets/variables nos 6 repos | [MANUAL-STEPS.md §4](MANUAL-STEPS.md#4-configurar-github-secretsvariables) |
| Depois | Disparar deploy da plataforma | [MANUAL-STEPS.md §6](MANUAL-STEPS.md#6-push-em-master-do-orchestrator-a-partir-daqui-é-automático) |
| Depois | Fluxo automático completo | [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md) |

---

> **Você está em:** [1. Bootstrap](BOOTSTRAP.md) → **próxima parada:** [2. GitHub App →](SECURITY-SETUP.md#1-github-app-para-gitops-substitui-pat)

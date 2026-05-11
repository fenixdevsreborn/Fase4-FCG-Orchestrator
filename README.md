# Fase4-FCG-Orchestrator — Plataforma + Gateway

Este repositório é o **centro da plataforma FCG na Fase 4**. Contém:

- **Gateway YARP** (`src/Gateway.Api/`) — entrypoint HTTP único
- **Manifestos Kubernetes locais** (`k8s/`) — para Docker Desktop / cluster de dev
- **Plataforma AWS Fase 4**: Terraform (`infra/`), Helm chart `fcg-platform` (`deploy/helm/`), GitOps Argo CD (`gitops/`), scripts de bootstrap e smoke-test (`scripts/`)
- **Pipelines GitHub Actions** (`.github/workflows/`) — `terraform-aws.yml` e `gateway-api-ci-cd.yml`; o frontend tem pipeline própria no repo `Fase4-FCG-Frontend`

> **Branch alvo das pipelines:** `master`.
> **Registries:** AWS ECR (privado, exigido pelo Tech Challenge) **e** Docker Hub (público, paralelo).
> **Repositórios padronizados:** `Fase4-FCG-Orchestrator`, `Fase4-FCG-UsersAPI`, `Fase4-FCG-CatalogAPI`, `Fase4-FCG-PaymentsAPI`, `Fase4-FCG-NotificationsAPI`, `Fase4-FCG-Frontend`.
> **Perfil Free Tier:** um único EKS com até **2 nós `m7i-flex.large`**, um ALB compartilhado, RDS consolidado, OpenSearch single-node e frontend servido na raiz `/`.

## ⚠️ Antes de qualquer deploy automático leia, nesta ordem:

1. 🚀 **[docs/BOOTSTRAP.md](docs/BOOTSTRAP.md)** — bootstrap AWS via GitHub Actions (sem instalar nada localmente) **ou** via Terraform local. Inclui passo a passo para criar Access Key na tela do IAM Console.
2. 📋 **[docs/MANUAL-STEPS.md](docs/MANUAL-STEPS.md)** — checklist completo: repos GitHub + Docker Hub, GitHub App, secrets, Argo CD.
3. 🔑 **[docs/SECRETS-MANAGEMENT.md](docs/SECRETS-MANAGEMENT.md)** — Cloudflare (por que não serve), Doppler, GitHub Org Secrets, OIDC. **Leia para decidir como gerenciar secrets sem configuração manual por repo.**
4. 📘 [docs/DEPLOY-AUTOMATIC.md](docs/DEPLOY-AUTOMATIC.md) — fluxo automático ponta-a-ponta.
5. 🔐 [docs/SECURITY-SETUP.md](docs/SECURITY-SETUP.md) — GitHub App (GitOps), branch protection, secret scanning.
6. 🚑 [docs/DISASTER-RECOVERY.md](docs/DISASTER-RECOVERY.md) — rollback, restore RDS, reconstrução de cluster.
7. 📊 [docs/ENV-VARS.md](docs/ENV-VARS.md) — padrão de variáveis de ambiente.
8. 🎯 [docs/FASE4-COMPLIANCE.md](docs/FASE4-COMPLIANCE.md) — mapa dos requisitos do Tech Challenge.
9. 📐 [docs/AWS-PLATFORM.md](docs/AWS-PLATFORM.md) — visão geral da arquitetura.
10. 💡 [docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md) — melhorias implementadas e pendentes.

## Resumo de **toda configuração manual obrigatória** (TL;DR)

| # | Tarefa | Onde | Doc |
|---|--------|------|-----|
| 1 | Criar usuário IAM `fcg-bootstrap-admin` + Access Key (selecionar "Outros") | AWS Console | BOOTSTRAP.md |
| 2 | Criar 6 repos GitHub `Fase4-FCG-*` com **branch padrão `master`** | github.com | MANUAL-STEPS §1 |
| 3 | Criar repos Docker Hub dos serviços que ainda publicam imagem pública + gerar PAT Read/Write | hub.docker.com | MANUAL-STEPS §2 |
| 4 | Criar **GitHub App `FCG GitOps`** + baixar `.pem` | github.com | SECURITY-SETUP.md §1 |
| 5 | Configurar secrets temporários + disparar workflow `bootstrap-aws` | GitHub Actions | BOOTSTRAP.md §Caminho A |
| 6 | **Excluir** Access Key e secrets de bootstrap do GitHub e da AWS | AWS + GitHub | BOOTSTRAP.md §Passo 6 |
| 7 | Configurar **GitHub Org Secrets** (se org) ou **Doppler** (se conta pessoal) | github.com ou doppler.com | SECRETS-MANAGEMENT.md |
| 8 | Editar `gitops/argocd/*.yaml` → `repoURL` real | git commit | MANUAL-STEPS §5 |
| 9 | Push em `master` → dispara Terraform da plataforma (EKS, ECR, RDS...) | terminal | MANUAL-STEPS §6 |
| 10 | `workflow_dispatch` em cada API (primeira imagem) | GitHub UI | MANUAL-STEPS §7 |
| 11 | `kubectl apply -f gitops/argocd/` (registra Argo CD) | terminal | MANUAL-STEPS §8 |

> **Pastas locais já foram renomeadas** para `Fase4-FCG-*`. Renomeie também no GitHub em Settings → Repository name se necessário.

---

## Estrutura

## Estrutura

```
Fase4-FCG-Orchestrator/
├── .github/workflows/       # terraform-aws.yml + gateway-api-ci-cd.yml (push em master)
├── infra/
│   ├── terraform/bootstrap/ # OIDC, IAM role GitHub Actions, S3 state, DynamoDB lock
│   └── terraform/aws/       # EKS, ECR (6 repos), RDS consolidado, MQ, Redis, OpenSearch, DynamoDB
├── deploy/helm/fcg-platform/ # Chart Helm de produção (Argo CD)
├── gitops/argocd/           # AppProject + Application (targetRevision: master)
├── scripts/                 # render-values.sh + smoke-test.ps1 (ALB)
├── src/                     # Gateway.Api (.NET) — entrypoint YARP
├── docs/                    # MANUAL-STEPS, DEPLOY-AUTOMATIC, FASE4-COMPLIANCE, IMPROVEMENTS
├── k8s/
│   ├── namespace.yaml                    # Namespace único para todos os serviços
│   ├── configmap.yaml                    # Configurações compartilhadas (RabbitMQ, etc)
│   ├── secrets.yaml                      # Secrets compartilhados (templates)
│   ├── rabbitmq/                         # RabbitMQ compartilhado
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   ├── users-api/                        # UsersAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── catalog-api/                      # CatalogAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── payments-api/                     # PaymentsAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── notifications-api/                # NotificationsAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── postgres-users/                   # PostgreSQL INDIVIDUAL para UsersAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── postgres-catalog/                 # PostgreSQL INDIVIDUAL para CatalogAPI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── ingress.yaml                      # Ingress
│   ├── kustomization.yaml                # Kustomize para deploy simplificado
│   └── README.md                         # Documentação completa
└── README.md                             # Este arquivo
```

## Pré-requisitos

1. **Docker Desktop** com Kubernetes habilitado
   - Certifique-se de que o Kubernetes está ativado nas configurações do Docker Desktop
   - Verifique com: `kubectl cluster-info`

2. **kubectl** configurado e conectado ao cluster
   - Verifique com: `kubectl get nodes`

3. **Imagens Docker** construídas localmente
   - As imagens dos microsserviços devem estar disponíveis no Docker Desktop
   - Para build local, execute os Dockerfiles de cada microsserviço

## Build das Imagens Docker

Antes de fazer o deploy, você precisa construir as imagens Docker de cada microsserviço.

### Método Automatizado (Recomendado)

Use o script PowerShell que constrói todas as imagens automaticamente:

```powershell
cd Fase4-FCG-Orchestrator
.\build-images.ps1
```

Este script irá:
- Verificar se o Docker está disponível
- Construir todas as 4 imagens na ordem correta
- Exibir um resumo com sucesso/erros

### Método Manual

Se preferir construir manualmente:

#### UsersAPI
```powershell
cd ..\Fase4-FCG-UsersAPI
docker build -t usersapi-api:8 -f Dockerfile .
```

#### CatalogAPI
```powershell
cd ..\Fase4-FCG-CatalogAPI
docker build -t catalogapi:latest -f Dockerfile .
```

#### PaymentsAPI
```powershell
cd ..\Fase4-FCG-PaymentsAPI
docker build -t payments-api:latest -f Dockerfile .
```

#### NotificationsAPI
```powershell
cd ..\Fase4-FCG-NotificationsAPI\src
docker build -t notifications-worker:1 -f Dockerfile .
```

#### Frontend
```powershell
cd ..\Fase4-FCG-Frontend
docker build -t frontend-web:latest -f Dockerfile .
```

### Verificar Imagens Construídas

```powershell
docker images | findstr "usersapi catalogapi payments notifications frontend"
```

## Fluxo Completo

### Opção 1: Build e Deploy Automatizado (Recomendado)

Execute tudo de uma vez:

```powershell
cd Fase4-FCG-Orchestrator
.\build-and-deploy.ps1
```

Este script irá:
1. Construir todas as imagens Docker
2. Fazer o deploy no Kubernetes
3. Exibir um resumo completo

### Opção 2: Passo a Passo

#### 1. Construir Imagens Docker

```powershell
cd Fase4-FCG-Orchestrator
.\build-images.ps1
```

#### 2. Deploy no Kubernetes

### Deploy Completo (Recomendado)

Use o Kustomize para aplicar todos os manifestos de uma vez:

```powershell
cd Fase4-FCG-Orchestrator
kubectl apply -k k8s/
```

### Deploy Manual (Ordem Específica)

Se preferir aplicar na ordem específica:

```powershell
# 1. Namespace
kubectl apply -f k8s/namespace.yaml

# 2. Secrets e ConfigMaps compartilhados
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml

# 3. RabbitMQ
kubectl apply -f k8s/rabbitmq/

# 4. PostgreSQL para UsersAPI
kubectl apply -f k8s/postgres-users/

# 5. PostgreSQL para CatalogAPI
kubectl apply -f k8s/postgres-catalog/

# 6. Microsserviços
kubectl apply -f k8s/users-api/
kubectl apply -f k8s/catalog-api/
kubectl apply -f k8s/payments-api/
kubectl apply -f k8s/notifications-api/

# 7. Ingress (opcional)
kubectl apply -f k8s/ingress.yaml
```

## Verificação

### Verificar Status dos Pods

```powershell
# Ver todos os recursos no namespace
kubectl get all -n fiap-gamestore

# Ver pods específicos
kubectl get pods -n fiap-gamestore

# Ver status detalhado
kubectl get pods -n fiap-gamestore -o wide
```

### Verificar Logs

```powershell
# Logs do UsersAPI
kubectl logs -f deployment/users-api -n fiap-gamestore

# Logs do CatalogAPI
kubectl logs -f deployment/catalog-api -n fiap-gamestore

# Logs do PaymentsAPI
kubectl logs -f deployment/payments-api -n fiap-gamestore

# Logs do NotificationsAPI
kubectl logs -f deployment/notifications-api -n fiap-gamestore
```

### Verificar Services

```powershell
# Listar services
kubectl get svc -n fiap-gamestore

# Detalhes de um service
kubectl describe svc users-api-service -n fiap-gamestore
```

## Acessar Serviços

### Port-Forward para Acesso Local

#### Gateway API (Recomendado - Acesso Unificado)

```powershell
# Método 1: Script automatizado (recomendado)
.\start-gateway.ps1

# Método 2: Manual
kubectl port-forward svc/gateway-api-service 5005:8080 -n fiap-gamestore
```

**Acessar Swagger Unificado**: `http://localhost:5005`

O Gateway agrega todas as APIs:
- Users API: `http://localhost:5005/api/users/*`
- Catalog API: `http://localhost:5005/api/games/*`
- Payments API: `http://localhost:5005/api/payments/*`
- Notifications API: `http://localhost:5005/api/notifications/*`

#### Acesso Individual (Alternativo)

```powershell
# UsersAPI
kubectl port-forward svc/users-api-service 8080:8080 -n fiap-gamestore
# Acessar: http://localhost:8080

# CatalogAPI
kubectl port-forward svc/catalog-api-service 8081:8080 -n fiap-gamestore
# Acessar: http://localhost:8081

# RabbitMQ Management UI
kubectl port-forward svc/rabbitmq-service 15672:15672 -n fiap-gamestore
# Acessar: http://localhost:15672 (guest/guest)
```

### Acesso via NodePort (Acesso Permanente)

Os seguintes serviços estão expostos via NodePort para acesso permanente sem necessidade de port-forward:

#### RabbitMQ Management UI

**URL**: `http://localhost:31672` (Docker Desktop) ou `http://<node-ip>:31672`

**Credenciais**: 
- Usuário: `guest`
- Senha: `guest`

**Serviço**: `rabbitmq-management` (NodePort 31672)

#### UsersAPI Swagger

**URL**: `http://localhost:30080/swagger` (Docker Desktop) ou `http://<node-ip>:30080/swagger`

**Serviço**: `users-api-swagger` (NodePort 30080)

#### CatalogAPI Swagger

**URL**: `http://localhost:30081/swagger` (Docker Desktop) ou `http://<node-ip>:30081/swagger`

**Serviço**: `catalog-api-swagger` (NodePort 30081)

**Nota**: Para obter o IP do node em clusters externos, use: `kubectl get nodes -o wide`. No Docker Desktop, use `localhost`.

## Comunicação entre Serviços

- **CatalogAPI → UsersAPI**: `http://users-api-service:8080/api/users/me`
- **Todos → RabbitMQ**: `rabbitmq-service:5672`
- **CatalogAPI → PostgreSQL**: `postgres-catalog-service:5432` (banco individual)
- **UsersAPI → PostgreSQL**: `postgres-users-service:5432` (banco individual)

**Nota**: Cada serviço tem seu próprio PostgreSQL isolado. Não há compartilhamento de banco de dados entre serviços.

## Variáveis de Ambiente

### ConfigMaps

Configurações não sensíveis são armazenadas em ConfigMaps:
- URLs de serviços
- Nomes de filas/tópicos
- Configurações de ambiente

### Secrets

Dados sensíveis são armazenados em Secrets:
- Connection strings de banco de dados
- Senhas
- JWT keys
- Credenciais RabbitMQ

⚠️ **IMPORTANTE**: Os Secrets neste repositório contêm credenciais em texto plano apenas para desenvolvimento. Em produção, use:
- Sealed Secrets
- External Secrets Operator
- Azure Key Vault / AWS Secrets Manager / GCP Secret Manager
- HashiCorp Vault

## Troubleshooting

### Pods não iniciam

```powershell
# Verificar eventos
kubectl get events -n fiap-gamestore --sort-by='.lastTimestamp'

# Descrever pod para ver erros
kubectl describe pod <pod-name> -n fiap-gamestore

# Ver logs anteriores se o pod reiniciou
kubectl logs <pod-name> -n fiap-gamestore --previous
```

### Problemas de Conexão

```powershell
# Verificar se os services estão corretos
kubectl get svc -n fiap-gamestore

# Testar conectividade entre pods
kubectl exec -it <pod-name> -n fiap-gamestore -- ping rabbitmq-service
```

### Problemas de Storage

```powershell
# Verificar PVCs
kubectl get pvc -n fiap-gamestore

# Ver detalhes do PVC
kubectl describe pvc postgres-users-pvc -n fiap-gamestore
```

## Limpeza

### Remover Tudo

```powershell
# Remover todos os recursos
kubectl delete -k k8s/

# Ou remover namespace (remove tudo dentro)
kubectl delete namespace fiap-gamestore
```

⚠️ **ATENÇÃO**: Remover o namespace também remove os PVCs e dados persistentes!

## Ordem de Deploy

1. Namespace
2. Secrets e ConfigMaps compartilhados
3. RabbitMQ
4. **PostgreSQL INDIVIDUAL para UsersAPI** (Deployment, Service, PVC, ConfigMap, Secret)
5. **PostgreSQL INDIVIDUAL para CatalogAPI** (Deployment, Service, PVC, ConfigMap, Secret)
6. UsersAPI (aguarda postgres-users estar pronto)
7. CatalogAPI (aguarda postgres-catalog estar pronto)
8. PaymentsAPI
9. NotificationsAPI
10. Ingress (opcional)

## Validação

Após o deploy, valide:

- ✅ Todos os Pods estão Running
- ✅ Comunicação entre serviços funciona
- ✅ Fluxo de cadastro de usuário funciona
- ✅ Fluxo de compra de jogo funciona
- ✅ Eventos no RabbitMQ são processados corretamente

## Suporte

Para problemas ou dúvidas, consulte:
- Documentação do Kubernetes: https://kubernetes.io/docs/
- Logs dos pods: `kubectl logs -f <pod-name> -n fiap-gamestore`
- Eventos do cluster: `kubectl get events -n fiap-gamestore --sort-by='.lastTimestamp'`

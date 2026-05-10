# FASE 4 — Mapa de cumprimento dos requisitos

Cruzamento dos requisitos do Tech Challenge (FASE 4) com a implementação atual.

| # | Requisito | Status | Onde está |
|---|-----------|:------:|-----------|
| 1.1 | Cluster Kubernetes gerenciado em nuvem | ✅ | `infra/terraform/aws/main.tf` — módulo `terraform-aws-modules/eks/aws` v20 |
| 1.2 | Registry privado nativo da nuvem | ✅ | `aws_ecr_repository.repositories` para 5 serviços |
| 1.3 | Exposição via Load Balancer / Ingress Controller | ✅ | `eks_blueprints_addons` instala AWS Load Balancer Controller; chart usa `Ingress` ALB |
| 1.4 | Não usar IaaS isolado | ✅ | Workloads rodam em EKS managed node groups |
| 2.1 | NoSQL (MongoDB **ou** DynamoDB) | ✅ | `aws_dynamodb_table.catalog_metadata` + `CatalogAPI/Infrastructure/Services/GameMetadataStore.cs` (`AWSSDK.DynamoDBv2`) |
| 2.2 | Cache distribuído (Redis) | ✅ | `aws_elasticache_replication_group.redis` + `CatalogAPI/Infrastructure/Services/CatalogCacheService.cs` (`StackExchange.Redis` via `IDistributedCache`) |
| 3.1 | Busca avançada Elasticsearch/OpenSearch | ✅ | `aws_opensearch_domain.catalog` + `OpenSearchGameSearchService.cs` |
| 3.2 | Sincronização de índice no CatalogAPI | ✅ | `CreateGameCommandHandler` / `UpdateGameCommandHandler` / `DeleteGameCommandHandler` chamam o serviço de busca |
| 3.3 | Endpoint `/search` com fuzzy + relevância | ✅ | `GamesController.V1` `[HttpGet("search")]` + `Fuzziness.Auto` em `OpenSearchGameSearchService.cs:73` |
| 4.1 | Pipeline GitHub Actions / Azure DevOps | ✅ | 5 workflows em `.github/workflows/` (1 Terraform + 4 APIs + 1 Gateway) |
| 4.2 | Build & Test | ✅ | `dotnet build` + `dotnet test` em todas as APIs |
| 4.3 | Containerização com tags | ✅ | `${GITHUB_SHA::12}` em todos os pipelines |
| 4.4 | Security scan (desejável) | ✅ | `aquasecurity/trivy-action` com severity CRITICAL/HIGH + `dotnet list package --vulnerable` |
| 4.5 | Push no Registry da nuvem | ✅ | `aws-actions/amazon-ecr-login` + `docker push` |
| 4.6 | Deploy sem downtime (rolling update) | ✅ | Helm chart com `strategy.type: RollingUpdate` + `maxUnavailable: 0` em `templates/deployment.yaml` |
| 5.1 | Zero hardcoded credentials | ✅ | Senhas geradas por `random_password` no Terraform; nenhuma string sensível em YAML |
| 5.2 | Injeção via Secrets Manager + ESO | ✅ | `aws_secretsmanager_secret.application` + `ExternalSecret` no chart (`templates/externalsecret.yaml`) |
| 4.x | Pipeline cobre **no mínimo** UsersAPI e CatalogAPI | ✅ | + PaymentsAPI + NotificationsAPI + Gateway |

## Itens "desejáveis" entregues além do mínimo

- **GitOps com Argo CD** (`gitops/argocd/`) — disparo de deploy via commit em `values-prod.yaml` (branch `master`)
- **Bootstrap automatizado** (`infra/terraform/bootstrap/`) — provedor OIDC + IAM role + state backend
- **HPA** em todos os serviços (`templates/hpa.yaml`)
- **IRSA** dedicado para o CatalogAPI acessar DynamoDB sem credenciais de longa duração
- **Auditoria de pacotes NuGet** em todas as pipelines (falha em High/Critical)
- **Multi-AZ** em RDS subnet group, OpenSearch (`zone_awareness_enabled`) e EKS
- **Push paralelo Docker Hub** — além do ECR (privado, exigido pelo spec), as imagens são publicadas em Docker Hub para portabilidade e demo do vídeo Pitch

## Itens cuja garantia depende de configuração externa

| Item | O que falta | Como garantir |
|------|-------------|---------------|
| Domínio público no ALB | hostname customizado | adicionar Route53 + cert-manager (não exigido por FASE 4) |
| Logs centralizados | Fluentbit/CloudWatch agent | habilitar `enable_aws_for_fluentbit` no `eks_blueprints_addons` |
| HA do RabbitMQ | broker em modo `CLUSTER_MULTI_AZ` | trocar `deployment_mode` em `aws_mq_broker.rabbitmq` |
| Snapshot final do RDS | `skip_final_snapshot = false` | ajustar para produção real |

## Evidências para o vídeo Pitch

1. **Mostrar painel AWS**: Console EKS → cluster `fcg-prod`; Console ECR → 5 repositórios.
2. **Mostrar pods rodando**: `kubectl -n fcg-platform get pods,svc,ingress`.
3. **Live deploy**: alterar um endpoint trivial em `Fase4-FCG-CatalogAPI` → `git push origin master` → mostrar pipeline GitHub Actions concluindo, Argo CD sincronizando, e novo pod rolling-update no `kubectl get pods -w`.
4. **Cache em ação**: `curl /api/v1/games` duas vezes; primeiro hit gera log de DB query, segundo hit não (logs do CatalogAPI).
5. **Busca fuzzy**: `curl "/api/v1/games/search?q=zeldaa"` retornando "The Legend of Zelda" com `score` ordenado.
6. **NoSQL**: console DynamoDB → tabela `fcg-prod-catalog-metadata` com items.

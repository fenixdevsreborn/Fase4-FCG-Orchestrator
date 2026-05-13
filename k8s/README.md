# Kubernetes Manifests - Documentação Técnica

Este diretório contém todos os manifestos Kubernetes para orquestrar os microsserviços da FIAP Cloud Games.

## Estrutura de Arquivos

### Recursos Compartilhados

- **namespace.yaml**: Namespace `fiap-gamestore` para isolar todos os recursos
- **configmap.yaml**: Configurações compartilhadas (RabbitMQ, filas)
- **secrets.yaml**: Secrets compartilhados (credenciais RabbitMQ)

### RabbitMQ (Compartilhado)

- **rabbitmq/deployment.yaml**: Deployment do RabbitMQ
- **rabbitmq/service.yaml**: Service ClusterIP para comunicação interna
- **rabbitmq/pvc.yaml**: PersistentVolumeClaim para dados persistentes

### PostgreSQL Individual

Cada serviço que precisa de banco de dados tem seu próprio PostgreSQL:

#### PostgreSQL para UsersAPI
- **postgres-users/deployment.yaml**: Deployment do PostgreSQL
- **postgres-users/service.yaml**: Service `postgres-users-service`
- **postgres-users/pvc.yaml**: PersistentVolumeClaim
- **postgres-users/configmap.yaml**: Configurações do banco
- **postgres-users/secret.yaml**: Credenciais do banco

#### PostgreSQL para CatalogAPI
- **postgres-catalog/deployment.yaml**: Deployment do PostgreSQL
- **postgres-catalog/service.yaml**: Service `postgres-catalog-service`
- **postgres-catalog/pvc.yaml**: PersistentVolumeClaim
- **postgres-catalog/configmap.yaml**: Configurações do banco
- **postgres-catalog/secret.yaml**: Credenciais do banco

### Microsserviços

Cada microsserviço tem sua própria pasta com:
- **deployment.yaml**: Deployment com configurações do serviço
- **service.yaml**: Service ClusterIP para comunicação interna
- **configmap.yaml**: Configurações não sensíveis
- **secret.yaml**: Credenciais e dados sensíveis

## Configurações Importantes

### Nomes de Services

- **users-api-service**: Porta 8080
- **catalog-api-service**: Porta 8080
- **payments-api-service**: Porta 80 (targetPort 8080)
- **notifications-api-service**: Porta 80 (targetPort 8080)
- **rabbitmq-service**: Porta 5672 (AMQP), 15672 (Management)
- **postgres-users-service**: Porta 5432
- **postgres-catalog-service**: Porta 5432

### Variáveis de Ambiente

#### UsersAPI
- `ConnectionStrings__DefaultConnection`: Connection string do PostgreSQL
- `RabbitMQ__Host`: `rabbitmq-service`
- `Jwt__Key`: Chave secreta para JWT

#### CatalogAPI
- `ConnectionStrings__CatalogDatabase`: Connection string do PostgreSQL
- `RabbitMQ__Host`: `rabbitmq-service`
- `Jwt__Key`: mesma chave usada pela UsersAPI
- `Jwt__Issuer`: `UsersAPI`
- `Jwt__Audience`: `UsersAPI`

#### PaymentsAPI
- `RabbitMQ__Host`: `rabbitmq-service`

#### NotificationsAPI
- `RABBITMQ_HOST`: `rabbitmq-service`
- `QUEUE_USER_CREATED`: Nome da fila para eventos de usuário criado
- `QUEUE_PAYMENT_PROCESSED`: Nome da fila para eventos de pagamento processado

## Health Checks

Todos os Deployments têm liveness e readiness probes configurados:

- **UsersAPI**: `/health` na porta 8080
- **CatalogAPI**: `/health` na porta 8080
- **PostgreSQL**: `pg_isready` command
- **RabbitMQ**: `rabbitmq-diagnostics check_port_connectivity`

## Resource Limits

### Requests (Garantidos)
- **UsersAPI**: CPU 250m, Memory 256Mi
- **CatalogAPI**: CPU 500m, Memory 512Mi
- **PaymentsAPI**: CPU 250m, Memory 256Mi
- **NotificationsAPI**: CPU 250m, Memory 256Mi
- **PostgreSQL**: CPU 500m, Memory 512Mi
- **RabbitMQ**: CPU 500m, Memory 512Mi

### Limits (Máximos)
- **UsersAPI**: CPU 500m, Memory 512Mi
- **CatalogAPI**: CPU 1000m, Memory 1Gi
- **PaymentsAPI**: CPU 500m, Memory 512Mi
- **NotificationsAPI**: CPU 500m, Memory 512Mi
- **PostgreSQL**: CPU 2000m, Memory 2Gi
- **RabbitMQ**: CPU 1000m, Memory 1Gi

## Init Containers

Os Deployments de UsersAPI e CatalogAPI têm init containers que aguardam o PostgreSQL estar pronto antes de iniciar:

```yaml
initContainers:
- name: wait-for-postgres
  image: postgres:16-alpine
  command:
  - sh
  - -c
  - |
    until pg_isready -h postgres-users-service -p 5432 -U postgres; do
      echo "Waiting for postgres-users-service..."
      sleep 2
    done
```

## Persistência de Dados

### PersistentVolumeClaims

- **rabbitmq-pvc**: 5Gi para dados do RabbitMQ
- **postgres-users-pvc**: 10Gi para banco de dados do UsersAPI
- **postgres-catalog-pvc**: 10Gi para banco de dados do CatalogAPI

Todos os PVCs usam `ReadWriteOnce` access mode.

## Segurança

### Security Context

Todos os containers têm security context configurado:
- `allowPrivilegeEscalation: false`
- `runAsNonRoot: true`
- `runAsUser: 1000` (para aplicações) ou `999` (para PostgreSQL/RabbitMQ)
- `capabilities.drop: ALL`

## Ordem de Dependências

1. Namespace
2. Secrets e ConfigMaps compartilhados
3. RabbitMQ (não tem dependências)
4. PostgreSQL para UsersAPI (não tem dependências)
5. PostgreSQL para CatalogAPI (não tem dependências)
6. UsersAPI (depende de postgres-users-service e rabbitmq-service)
7. CatalogAPI (depende de postgres-catalog-service, rabbitmq-service e users-api-service)
8. PaymentsAPI (depende de rabbitmq-service)
9. NotificationsAPI (depende de rabbitmq-service)

## Troubleshooting

### Verificar Dependências

```powershell
# Verificar se os services estão criados
kubectl get svc -n fiap-gamestore

# Verificar se os pods podem resolver os nomes DNS
kubectl exec -it <pod-name> -n fiap-gamestore -- nslookup rabbitmq-service
```

### Verificar Logs de Init Containers

```powershell
# Ver logs do init container
kubectl logs <pod-name> -n fiap-gamestore -c wait-for-postgres
```

### Verificar PVCs

```powershell
# Ver status dos PVCs
kubectl get pvc -n fiap-gamestore

# Ver detalhes de um PVC
kubectl describe pvc postgres-users-pvc -n fiap-gamestore
```

## Atualizações

### Atualizar um Deployment

```powershell
# Atualizar imagem
kubectl set image deployment/catalog-api catalog-api=catalogapi:v1.1.0 -n fiap-gamestore

# Verificar rollout
kubectl rollout status deployment/catalog-api -n fiap-gamestore
```

### Atualizar ConfigMap

```powershell
# Editar ConfigMap
kubectl edit configmap catalog-api-config -n fiap-gamestore

# Reiniciar pods para aplicar mudanças
kubectl rollout restart deployment/catalog-api -n fiap-gamestore
```

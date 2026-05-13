# Variáveis de Ambiente — Padrão FCG

Este documento define o padrão de nomenclatura e lista todas as variáveis de ambiente da plataforma.

---

## Padrão adotado: .NET nested config (`__`)

Todas as variáveis usam o formato `Secao__Chave` (duplo underline), que é o padrão nativo do ASP.NET Core. Este formato mapeia diretamente para `appsettings.json`:

```json
{ "RabbitMQ": { "Host": "localhost" } }
```

Corresponde à variável de ambiente `RabbitMQ__Host=localhost`.

**NotificationsAPI — ação necessária:** o serviço atual usa o formato legado `RABBITMQ_HOST`, `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`. Migrar para `RabbitMQ__Host`, `RabbitMQ__Username`, `RabbitMQ__Password` no código-fonte e atualizar o `infra/terraform/aws/main.tf` no bloco `secret_payloads["notifications-api"]`.

---

## Tabela de variáveis por serviço

| Variável | Descrição | Tipo | UsersAPI | CatalogAPI | PaymentsAPI | NotificationsAPI | Gateway |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `ConnectionStrings__DefaultConnection` | RDS PostgreSQL (users_db) | Secret | X | | | | |
| `ConnectionStrings__CatalogDatabase` | RDS PostgreSQL (catalogdb) | Secret | | X | | | |
| `RabbitMQ__Host` | RabbitMQ service hostname | Secret | X | X | X | X | |
| `RabbitMQ__Username` | RabbitMQ username | Secret | X | X | X | X | |
| `RabbitMQ__Password` | RabbitMQ password | Secret | X | X | X | X | |
| `Jwt__Key` | Chave de assinatura JWT compartilhada | Secret | X | X | | | |
| `Jwt__Issuer` | Emissor esperado do JWT | Config | X | X | | | |
| `Jwt__Audience` | Audience esperada do JWT | Config | X | X | | | |
| `CatalogCache__ConnectionString` | ElastiCache Redis endpoint | Secret | | X | | | |
| `DynamoDb__TableName` | DynamoDB table name | Config | | X | | | |
| `DynamoDb__Region` | AWS region do DynamoDB | Config | | X | | | |
| `OpenSearch__Endpoint` | URL do domínio OpenSearch | Secret | | X | | | |
| `OpenSearch__IndexName` | Nome do índice OpenSearch | Config | | X | | | |
| `OpenSearch__Username` | OpenSearch master username | Secret | | X | | | |
| `OpenSearch__Password` | OpenSearch master password | Secret | | X | | | |
| `ASPNETCORE_ENVIRONMENT` | `Development` ou `Production` | Config | X | X | X | X | X |
| `ASPNETCORE_URLS` | Binding da API (`http://+:8080`) | Config | X | X | X | X | X |

---

## Em produção (AWS)

As variáveis são injetadas automaticamente via:
1. **Terraform** → cria secrets no AWS Secrets Manager com os valores reais
2. **External Secrets Operator** → sincroniza Secrets Manager → Kubernetes Secret
3. **Helm chart** → monta o Kubernetes Secret como variáveis de ambiente no Pod

Nenhuma variável é definida manualmente em YAML de produção.

Secrets criados pelo Terraform (`main.tf` → `local.secret_payloads`):
- `fcg/prod/users-api`
- `fcg/prod/catalog-api`
- `fcg/prod/payments-api`
- `fcg/prod/notifications-api`
- `fcg/prod/rabbitmq`

---

## Em desenvolvimento local (docker-compose)

As variáveis são definidas em `Fase4-FCG-Orchestrator/docker-compose.yml` com valores de desenvolvimento. Não usar `.env` com credenciais reais em desenvolvimento.

Exemplo para UsersAPI no compose:
```yaml
environment:
  ASPNETCORE_ENVIRONMENT: Development
  ASPNETCORE_URLS: http://+:8080
  ConnectionStrings__DefaultConnection: "Host=postgres-users;Port=5432;Database=users_db;Username=postgres;Password=postgres"
  RabbitMQ__Host: rabbitmq
  RabbitMQ__Username: guest
  RabbitMQ__Password: guest
  Jwt__Key: super-secret-dev-key-change-in-production-32chars
```

---

## Migrando NotificationsAPI para o padrão

**1. No código-fonte** (`src/NotificationsAPI/`), substituir:

| Antes (legado) | Depois (padrão) |
|---|---|
| `RABBITMQ_HOST` | `RabbitMQ__Host` |
| `RABBITMQ_USERNAME` | `RabbitMQ__Username` |
| `RABBITMQ_PASSWORD` | `RabbitMQ__Password` |

**2. Em `infra/terraform/aws/main.tf`**, atualizar o bloco `notifications-api` em `local.secret_payloads`:

```hcl
"notifications-api" = {
  RabbitMQ__Host     = local.rabbitmq_host      # era RABBITMQ_HOST
  RabbitMQ__Username = var.mq_username           # era RABBITMQ_USERNAME
  RabbitMQ__Password = random_password.rabbitmq.result  # era RABBITMQ_PASSWORD
}
```

**3. Em `docker-compose.yml`**, atualizar as variáveis do serviço `notifications-api`.

**4. Após a migração**, rodar `terraform apply` para atualizar o Secrets Manager na AWS.

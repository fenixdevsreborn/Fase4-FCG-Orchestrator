# Plataforma AWS — Visão geral

A entrega cloud-native da FCG (Fase 4) vive **neste** repositório (`Fase2-Orchestrator`), junto com o Gateway. Todo o ciclo é automatizado por GitHub Actions; o que continua manual está consolidado em [MANUAL-STEPS.md](MANUAL-STEPS.md).

## Estrutura

| Caminho | Uso |
|---------|-----|
| `infra/terraform/bootstrap` | OIDC GitHub→AWS, IAM role, state backend (S3+DynamoDB) — `terraform apply` único, local |
| `infra/terraform/aws` | VPC, EKS, ECR, RDS, MQ, Redis, OpenSearch, DynamoDB, Secrets Manager — aplicado pelo CI |
| `deploy/helm/fcg-platform` | Chart Helm consumido pelo Argo CD |
| `gitops/argocd` | `AppProject` e `Application` |
| `scripts/render-values.sh` | Substitui placeholders em `values-prod.yaml` a partir dos outputs do Terraform |
| `scripts/smoke-test.ps1` | Validação pós-deploy do ALB |

## Documentação

- 📘 [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md) — fluxo ponta-a-ponta (manual + automático)
- 📋 [MANUAL-STEPS.md](MANUAL-STEPS.md) — checklist do que precisa ser feito à mão
- 🔐 [GITHUB_OIDC_IAM.md](GITHUB_OIDC_IAM.md) — detalhes do OIDC (referência; agora automatizado pelo bootstrap)
- 🎯 [FASE4-COMPLIANCE.md](FASE4-COMPLIANCE.md) — mapa de cumprimento dos requisitos do Tech Challenge

## Fluxo resumido

```
[bootstrap local]  →  [push master Orchestrator]  →  [terraform apply via CI]
                                                          ↓
                                                  [render values-prod.yaml]
                                                          ↓
                                                  [commit em master]
                                                          ↓
[push master em qualquer API]  →  [build+push ECR + atualiza values-prod.yaml]
                                                          ↓
                                              [Argo CD detecta mudança]
                                                          ↓
                                            [rolling update no EKS]
```

## Política do Trivy (CI)

Os workflows das APIs já operam em modo estrito (`exit-code: "1"`, `severity: CRITICAL,HIGH`). Para relaxar durante experimentação, ajustar nos workflows individuais.

## Portas Gateway ↔ Helm

O chart define `payments-api-service` e `notifications-api-service` com **porta 80** → `targetPort: 8080`. O `appsettings.json` do Gateway em produção usa `:80` nesses destinos (já alinhado).

## Smoke test

```powershell
cd Fase2-Orchestrator
.\scripts\smoke-test.ps1 -BaseUrl http://<dns-do-alb>
```

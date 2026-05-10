# Runbook de Disaster Recovery

Procedimentos para as situações de falha mais comuns na plataforma FCG. Organizado do mais simples (rollback de código) ao mais complexo (reconstrução de cluster).

**Pré-requisito para qualquer operação kubectl:**
```powershell
aws eks update-kubeconfig --region us-east-1 --name fcg-prod
kubectl -n fcg-platform get pods  # verificar conectividade
```

---

## 1. Rollback de deploy (via Argo CD)

Quando um deploy quebrou algum serviço e você quer voltar para a versão anterior rapidamente.

**Opção A — Via Argo CD CLI (mais rápido):**
```powershell
# Instalar argocd CLI (se não tiver)
winget install ArgoProj.ArgoCD

# Login no Argo CD (obter a senha inicial)
$ARGOCD_PASS = kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
argocd login <argocd-server-url> --username admin --password $ARGOCD_PASS

# Ver histórico de deploys
argocd app history fcg-platform

# Fazer rollback para a revision anterior (substitua <N> pelo número)
argocd app rollback fcg-platform <N>

# Acompanhar o rollout
kubectl -n fcg-platform get pods -w
```

**Opção B — Via GitOps (revert de commit):**
```powershell
cd Fase4-FCG-Orchestrator
git log --oneline deploy/helm/fcg-platform/values-prod.yaml

# Reverter o commit de deploy problemático
git revert <commit-sha> --no-edit
git push origin master
# Argo CD detecta a mudança e faz rolling update de volta
```

**Opção C — Rollback kubectl direto (emergência):**
```powershell
# Listar histórico de rollout de um serviço específico
kubectl -n fcg-platform rollout history deployment/users-api

# Fazer rollback para versão anterior
kubectl -n fcg-platform rollout undo deployment/users-api

# Verificar
kubectl -n fcg-platform rollout status deployment/users-api
```

---

## 2. Serviço específico em CrashLoop

```powershell
# Ver logs do container que está falhando
kubectl -n fcg-platform logs deployment/<serviço> --previous

# Ver eventos do pod
kubectl -n fcg-platform describe pod -l app=<serviço>

# Causas comuns e checklist:
# - Connection string errada: verificar ExternalSecret → kubectl get externalsecret -n fcg-platform
# - Secret não sincronizado: kubectl describe externalsecret <nome> -n fcg-platform
# - Imagem não encontrada no ECR: verificar se o push de CI foi bem-sucedido
# - Out of memory: verificar limits no values-prod.yaml
```

---

## 3. Argo CD fora de sincronia (OutOfSync persistente)

```powershell
# Forçar sincronização
argocd app sync fcg-platform --force

# Se não resolver (ex.: recursos órfãos bloqueando)
argocd app sync fcg-platform --force --replace

# Último recurso: recriar a Application
argocd app delete fcg-platform --yes
kubectl apply -f gitops/argocd/fcg-platform-project.yaml
kubectl apply -f gitops/argocd/fcg-platform-application.yaml
```

---

## 4. Restaurar banco de dados RDS de snapshot

Use quando os dados estiverem corrompidos ou perdidos e você precisa restaurar para um ponto anterior.

```powershell
# 1. No Console AWS → RDS → Automated backups → selecionar a instância
# 2. Actions → Restore to point in time
#    OU: Snapshots → selecionar snapshot manual → Restore snapshot

# Novo identifier (não pode sobrescrever a instância existente)
# Exemplo: fcg-prod-users-restored-20260509

# 3. Após o restore, atualizar a connection string no Secrets Manager
aws secretsmanager update-secret `
  --secret-id "fcg/prod/users-api" `
  --secret-string '{"ConnectionStrings__DefaultConnection":"Host=<novo-endpoint>;..."}'

# 4. Reiniciar os pods para que busquem o novo secret
kubectl -n fcg-platform rollout restart deployment/users-api
```

> **Atenção:** Restaurar para uma nova instância não remove a antiga. Custos de RDS aumentam até a instância antiga ser desligada manualmente.

---

## 5. Reconstruir cluster EKS (situação extrema)

Use quando o cluster inteiro está inacessível ou foi deletado acidentalmente.

```powershell
# 1. Reaplicar Terraform (recria EKS, addons, etc.)
cd Fase4-FCG-Orchestrator/infra/terraform/aws
terraform init `
  -backend-config="bucket=$TF_BUCKET" `
  -backend-config="key=aws/prod/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=$TF_LOCK" `
  -backend-config="encrypt=true"
terraform apply -var-file=environments/prod.tfvars

# 2. Atualizar kubeconfig para o novo cluster
aws eks update-kubeconfig --region us-east-1 --name fcg-prod

# 3. Aguardar addons ficarem prontos (External Secrets, Argo CD, ALB Controller)
kubectl -n external-secrets get pods -w
kubectl -n argocd get pods -w

# 4. Registrar a Application no Argo CD
kubectl apply -f gitops/argocd/fcg-platform-project.yaml
kubectl apply -f gitops/argocd/fcg-platform-application.yaml

# 5. Argo CD sincroniza e reinstala todos os serviços automaticamente
argocd app sync fcg-platform
```

---

## 6. State Terraform corrompido ou dessincronizado

```powershell
# Ver o que o Terraform conhece
terraform state list

# Remover um recurso da state sem destruir na AWS (use com cuidado)
terraform state rm aws_db_instance.postgres["users"]

# Reimportar um recurso existente na AWS para a state
terraform import aws_db_instance.postgres["users"] <db-identifier-na-aws>

# Nunca editar terraform.tfstate manualmente
# Se o arquivo estiver corrompido: restaurar da versão anterior no S3
aws s3 cp s3://<tfstate_bucket>/aws/prod/terraform.tfstate terraform.tfstate.backup
# verificar o conteúdo antes de usar
```

---

## 7. Pipeline travada (workflow aguardando ou falhando)

```powershell
# Via GitHub CLI (se disponível) — cancelar e re-triggar
gh run cancel <run-id> --repo <org>/Fase4-FCG-UsersAPI
gh workflow run users-api-ci-cd.yml --repo <org>/Fase4-FCG-UsersAPI --ref master

# Ou via GitHub UI: Actions → selecionar run → Cancel workflow
# Depois: Re-run all jobs
```

**Causas comuns de falha:**
| Sintoma | Causa | Solução |
|---|---|---|
| `ECR: unable to authenticate` | `AWS_GITHUB_ROLE_ARN` errado ou OIDC removido | Verificar secret + re-aplicar bootstrap |
| `docker push: denied` | Role não tem permissão ECR push | Re-aplicar `terraform apply` no bootstrap |
| `git push: forbidden` em GitOps step | GitHub App não instalado no Orchestrator | Instalar o App (ver `SECURITY-SETUP.md §1.3`) |
| `trivy-results.sarif: no such file` | Step de scan pulou mas upload-sarif rodou | Verificar condicionais `if:` no workflow |
| `values-prod.yaml: block not found` | Chave do serviço não existe no values | Verificar `deploy/helm/fcg-platform/values-prod.yaml` |

---

## 8. Objetivos de RTO / RPO

| Cenário | RTO (tempo para restaurar) | RPO (perda de dados) |
|---|---|---|
| Rollback de deploy (código) | 5-15 min via Argo CD | Zero (sem perda de dados) |
| Falha de pod individual | 1-5 min (K8s reinicia automaticamente) | Zero |
| Falha de nó EKS | 5-10 min (K8s reagenda pods) | Zero |
| Restauração de banco (RDS snapshot) | 30-60 min + downtime de migração | Até 5 min (último automated backup) |
| Reconstrução de cluster EKS | 20-40 min (Terraform + sincronização Argo CD) | Zero (dados no RDS/DynamoDB sobrevivem) |
| Região AWS inteira indisponível | Não coberto por esta arquitetura | — |

---

## Referências

- Fluxo de deploy: [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md)
- Configuração de secrets: [SECURITY-SETUP.md](SECURITY-SETUP.md)
- Smoke test pós-deploy: `scripts/smoke-test.ps1 -BaseUrl http://<alb-dns>`

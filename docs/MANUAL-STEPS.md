# Passos manuais (executar uma vez)

Tudo o que **não** é automatizado pelas pipelines. Após esta lista, todo deploy é disparado por `git push`.

## ✅ Checklist

- [ ] **Conta AWS** com permissão administrativa para o bootstrap
- [ ] **Repositórios GitHub** criados em `<org>/Fase2-Orchestrator`, `<org>/Fase2-UsersAPI`, `<org>/Fase2-CatalogAPI`, `<org>/Fase2-PaymentsAPI`, `<org>/Fase2-NotificationsAPI`, com `main` populada
- [ ] **`terraform apply` no stack bootstrap** (cria OIDC + IAM role + S3/DynamoDB)
- [ ] **Configurar GitHub secrets/variables** nos 5 repositórios
- [ ] **Editar `repoURL`** em `gitops/argocd/fcg-platform-application.yaml` e `fcg-platform-project.yaml` (ou confiar no render automático via `vars.GITOPS_REPO_URL`)
- [ ] **Push em `main` do Orchestrator** para disparar `terraform apply` da plataforma
- [ ] **Aprovar** no environment `prod` (se você ativou required reviewers)
- [ ] **Disparar `workflow_dispatch`** uma vez em cada API para subir as primeiras imagens em ECR
- [ ] **Aplicar manifests Argo CD** no cluster: `kubectl apply -f gitops/argocd/`

## Comandos para um setup limpo

```powershell
# 1. Bootstrap
cd Fase2-Orchestrator/infra/terraform/bootstrap
cp environments/prod.tfvars.example environments/prod.tfvars
# editar github_org
terraform init
terraform apply -var-file=environments/prod.tfvars

# 2. Capturar outputs
$ROLE = terraform output -raw github_actions_role_arn
$BUCKET = terraform output -raw tfstate_bucket
$LOCK = terraform output -raw tfstate_lock_table

# 3. Configurar GitHub via gh CLI (Orchestrator)
gh secret set AWS_GITHUB_ROLE_ARN  --body "$ROLE"  --repo "<org>/Fase2-Orchestrator"
gh variable set TF_STATE_BUCKET    --body "$BUCKET"  --repo "<org>/Fase2-Orchestrator"
gh variable set TF_LOCK_TABLE      --body "$LOCK"  --repo "<org>/Fase2-Orchestrator"
gh variable set GITOPS_REPO_URL    --body "https://github.com/<org>/Fase2-Orchestrator.git" --repo "<org>/Fase2-Orchestrator"

# 4. Configurar GitHub nas APIs (criar PAT GITOPS_TOKEN antes)
$REPOS = @("Fase2-UsersAPI","Fase2-CatalogAPI","Fase2-PaymentsAPI","Fase2-NotificationsAPI")
foreach ($r in $REPOS) {
  gh secret set AWS_GITHUB_ROLE_ARN --body "$ROLE" --repo "<org>/$r"
  gh secret set GITOPS_TOKEN --body "<PAT>" --repo "<org>/$r"
  gh variable set GITOPS_REPOSITORY --body "<org>/Fase2-Orchestrator" --repo "<org>/$r"
}

# 5. Push em main do Orchestrator (já contém código terraform)
cd Fase2-Orchestrator
git push origin main

# 6. (após apply) configurar Argo CD
aws eks update-kubeconfig --region us-east-1 --name fcg-prod
kubectl apply -f gitops/argocd/
```

## Itens que continuam sendo manuais por design

| Item | Por quê | Frequência |
|------|---------|-----------|
| `terraform apply` do stack `bootstrap` | Cria a role que o CI usará — chicken/egg | 1x; ou ao adicionar novo repo |
| Criação dos repositórios GitHub | Fora do escopo Terraform | 1x |
| Geração de `GITOPS_TOKEN` (PAT) | Credencial de usuário | 1x; rotação periódica |
| Aprovação no environment `prod` | Gate de segurança humano (opcional) | A cada apply |
| Edição de `repoURL` em `gitops/argocd/*.yaml` | Pode também ser feita pelo render automático | 1x |
| Aplicar `kubectl apply -f gitops/argocd/` no cluster | Argo CD precisa ser registrado uma vez | 1x |

## Referências cruzadas

- Visão completa do fluxo: [DEPLOY-AUTOMATIC.md](DEPLOY-AUTOMATIC.md)
- Detalhes do OIDC IAM: [GITHUB_OIDC_IAM.md](GITHUB_OIDC_IAM.md)
- Mapa FASE 4: [FASE4-COMPLIANCE.md](FASE4-COMPLIANCE.md)
- Stack bootstrap: [../infra/terraform/bootstrap/README.md](../infra/terraform/bootstrap/README.md)

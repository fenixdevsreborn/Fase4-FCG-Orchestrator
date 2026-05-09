#!/usr/bin/env bash
# Substitui placeholders em values-prod.yaml e nos manifests Argo CD usando outputs do Terraform.
# Uso (a partir da raiz do repo):
#   scripts/render-values.sh <terraform-output-json>
# Se nenhum arquivo for passado, lê de stdin.
set -euo pipefail

INPUT="${1:-/dev/stdin}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALUES="${ROOT}/deploy/helm/fcg-platform/values-prod.yaml"
ARGO_APP="${ROOT}/gitops/argocd/fcg-platform-application.yaml"
ARGO_PROJECT="${ROOT}/gitops/argocd/fcg-platform-project.yaml"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

ACCOUNT_ID="$(jq -r '.aws_account_id.value' "$INPUT")"
REGION="$(jq -r '.aws_region.value' "$INPUT")"
ECR_REGISTRY="$(jq -r '.ecr_registry.value' "$INPUT")"
IRSA_ROLE_ARN="$(jq -r '.catalog_irsa_role_arn.value' "$INPUT")"

if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "null" ]]; then
  echo "aws_account_id missing from terraform output" >&2
  exit 1
fi

# Substitui o placeholder de account ID nas imagens ECR e na anotação IRSA.
# Mantém a tag "initial" - o tag real vem dos pipelines de cada API.
sed -i.bak \
  -e "s|111111111111\.dkr\.ecr\.[a-z0-9-]*\.amazonaws\.com|${ECR_REGISTRY}|g" \
  -e "s|arn:aws:iam::111111111111:role/[A-Za-z0-9_-]*catalog-irsa[A-Za-z0-9_-]*|${IRSA_ROLE_ARN}|g" \
  "$VALUES"
rm -f "$VALUES.bak"

# Argo CD repoURL: substituído via env GITOPS_REPO_URL (se setado).
if [[ -n "${GITOPS_REPO_URL:-}" ]]; then
  for f in "$ARGO_APP" "$ARGO_PROJECT"; do
    sed -i.bak \
      -e "s|https://github.com/your-org/your-repo.git|${GITOPS_REPO_URL}|g" \
      "$f"
    rm -f "$f.bak"
  done
fi

echo "Rendered values-prod.yaml with account=${ACCOUNT_ID} region=${REGION}"
echo "  ecr_registry=${ECR_REGISTRY}"
echo "  catalog_irsa_role_arn=${IRSA_ROLE_ARN}"

#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${1:-infra/terraform/aws}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-fcg}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
CLUSTER_NAME="${CLUSTER_NAME:-${PROJECT_NAME}-${ENVIRONMENT}}"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

cd "${TF_DIR}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

state_has() {
  terraform state show "$1" >/dev/null 2>&1
}

import_if_missing() {
  local address="$1"
  local import_id="$2"

  if state_has "${address}"; then
    echo "State OK: ${address}"
    return 0
  fi

  echo "Adotando recurso existente: ${address} <- ${import_id}"
  if terraform import -input=false -var-file=environments/prod.tfvars "${address}" "${import_id}"; then
    echo "Import OK: ${address}"
    return 0
  else
    echo "Import ignorado: ${address} (${import_id}) nao existe ou ainda nao esta pronto."
    return 1
  fi
}

aws_query() {
  aws "$@" --output text 2>/dev/null || true
}

adopt_or_remove_helm_release() {
  local address="$1"
  local namespace="$2"
  local release="$3"

  if state_has "${address}"; then
    echo "State OK: ${address}"
    return 0
  fi

  if import_if_missing "${address}" "${namespace}/${release}"; then
    return 0
  fi

  if command -v helm >/dev/null 2>&1 && helm status "${release}" -n "${namespace}" >/dev/null 2>&1; then
    echo "Release Helm ${namespace}/${release} existe fora do state e nao foi importado. Removendo para recriacao pelo Terraform..."
    helm uninstall "${release}" -n "${namespace}" --wait --timeout 5m || true
  fi
}

echo "Recuperando recursos existentes que podem ter sido criados antes de uma falha de state..."

if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null

  adopt_or_remove_helm_release \
    'module.eks_blueprints_addons.module.aws_load_balancer_controller.helm_release.this[0]' \
    'kube-system' \
    'aws-load-balancer-controller'
  adopt_or_remove_helm_release \
    'module.eks_blueprints_addons.module.external_secrets.helm_release.this[0]' \
    'external-secrets' \
    'external-secrets'
  adopt_or_remove_helm_release \
    'module.eks_blueprints_addons.module.metrics_server.helm_release.this[0]' \
    'kube-system' \
    'metrics-server'
  adopt_or_remove_helm_release \
    'module.eks_blueprints_addons.module.argocd.helm_release.this[0]' \
    'argocd' \
    'argo-cd'
else
  echo "Cluster ${CLUSTER_NAME} ainda nao existe. Pulando imports Helm."
fi

if aws iam get-role --role-name "${STACK_NAME}-catalog-irsa" >/dev/null 2>&1; then
  import_if_missing 'module.catalog_irsa_role.aws_iam_role.this[0]' "${STACK_NAME}-catalog-irsa" || true
fi

catalog_policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${STACK_NAME}-catalog-dynamodb"
if aws iam get-policy --policy-arn "${catalog_policy_arn}" >/dev/null 2>&1; then
  import_if_missing 'aws_iam_policy.catalog_dynamodb' "${catalog_policy_arn}" || true
fi

data_sg_id="$(aws_query ec2 describe-security-groups \
  --region "${AWS_REGION}" \
  --filters "Name=group-name,Values=${STACK_NAME}-data-services" \
  --query 'SecurityGroups[0].GroupId')"
if [[ -n "${data_sg_id}" && "${data_sg_id}" != "None" ]]; then
  import_if_missing 'aws_security_group.data_services' "${data_sg_id}" || true
fi

if aws s3api head-bucket --bucket "${STACK_NAME}-platform-logs" 2>/dev/null; then
  import_if_missing 'aws_s3_bucket.logs' "${STACK_NAME}-platform-logs" || true
fi

if aws rds describe-db-subnet-groups --db-subnet-group-name "${STACK_NAME}-postgres" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_db_subnet_group.postgres' "${STACK_NAME}-postgres" || true
fi

if aws rds describe-db-instances --db-instance-identifier "${STACK_NAME}-postgres" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_db_instance.postgres' "${STACK_NAME}-postgres" || true
fi

if aws elasticache describe-cache-subnet-groups --cache-subnet-group-name "${STACK_NAME}-redis" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_elasticache_subnet_group.redis' "${STACK_NAME}-redis" || true
fi

if aws elasticache describe-replication-groups --replication-group-id "${STACK_NAME}-redis" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_elasticache_replication_group.redis' "${STACK_NAME}-redis" || true
fi

if aws opensearch describe-domain --domain-name "${STACK_NAME}-catalog" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_opensearch_domain.catalog' "${STACK_NAME}-catalog" || true
fi

if aws dynamodb describe-table --table-name "${STACK_NAME}-catalog-metadata" --region "${AWS_REGION}" >/dev/null 2>&1; then
  import_if_missing 'aws_dynamodb_table.catalog_metadata' "${STACK_NAME}-catalog-metadata" || true
fi

for repository in frontend-web gateway-api users-api catalog-api payments-api notifications-api; do
  if aws ecr describe-repositories --repository-names "${repository}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    import_if_missing "aws_ecr_repository.repositories[\"${repository}\"]" "${repository}" || true
  fi
done

for secret_key in users-api catalog-api payments-api notifications-api rabbitmq postgres-bootstrap; do
  secret_name="${PROJECT_NAME}/${ENVIRONMENT}/${secret_key}"
  secret_arn="$(aws_query secretsmanager describe-secret \
    --secret-id "${secret_name}" \
    --region "${AWS_REGION}" \
    --query ARN)"

  if [[ -n "${secret_arn}" && "${secret_arn}" != "None" ]]; then
    import_if_missing "aws_secretsmanager_secret.application[\"${secret_key}\"]" "${secret_arn}" || true
  fi
done

echo "Recuperacao de state concluida."

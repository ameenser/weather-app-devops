#!/usr/bin/env bash
set -Eeuo pipefail

# Files created by this script should only be readable by the current user.
umask 077

BOOTSTRAP_INPUTS_FILE="${HOME}/.vault-lab/bootstrap-inputs.env"
VAULT_KEYS_DIR="${HOME}/.vault-lab"
VAULT_KEYS_FILE="${VAULT_KEYS_DIR}/weather-app-vault.env"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-weather-app-q3-eks}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

if [[ ! -f "$BOOTSTRAP_INPUTS_FILE" ]]; then
  log_error "Bootstrap inputs file not found: $BOOTSTRAP_INPUTS_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$BOOTSTRAP_INPUTS_FILE"

: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}"
: "${JENKINS_USER:?JENKINS_USER is required}"
: "${JENKINS_API_TOKEN:?JENKINS_API_TOKEN is required}"
: "${SLACK_WEBHOOK_URL:?SLACK_WEBHOOK_URL is required}"
: "${MAKE_LOG_WEBHOOK_URL:?MAKE_LOG_WEBHOOK_URL is required}"

if [[ "$MAKE_LOG_WEBHOOK_URL" != https://* ]]; then
  log_error "MAKE_LOG_WEBHOOK_URL must use HTTPS"
  exit 1
fi



for command in aws kubectl jq openssl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    log_error "Required command is missing: $command"
    exit 1
  fi
done

mkdir -p "$VAULT_KEYS_DIR"
chmod 700 "$VAULT_KEYS_DIR"

log_info "Updating kubeconfig for EKS cluster: ${EKS_CLUSTER_NAME}"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --alias "$EKS_CLUSTER_NAME" \
  >/dev/null

KUBECTL=(kubectl --context "$EKS_CLUSTER_NAME")

log_info "Verifying Kubernetes API connectivity..."

"${KUBECTL[@]}" cluster-info >/dev/null

log_info "Kubernetes API is reachable."
log_info "Required environment variables and commands are available."
log_info "Vault keys file: $VAULT_KEYS_FILE"

log_info "Waiting for Vault pod to exist..."

for attempt in {1..60}; do
  if "${KUBECTL[@]}" get pod \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    >/dev/null 2>&1; then

    log_info "Vault pod exists."
    break
  fi

  if [[ "$attempt" -eq 60 ]]; then
    log_error "Vault pod did not appear after 5 minutes."
    exit 1
  fi

  sleep 5
done

log_info "Waiting for Vault pod to be scheduled..."

"${KUBECTL[@]}" wait \
  --namespace "$VAULT_NAMESPACE" \
  --for=condition=PodScheduled \
  "pod/${VAULT_POD}" \
  --timeout=5m

log_info "Vault pod is scheduled."
log_info "Waiting for Vault CLI to become available..."

for attempt in {1..60}; do
  STATUS_OUTPUT="$(
    "${KUBECTL[@]}" exec \
      --namespace "$VAULT_NAMESPACE" \
      "$VAULT_POD" \
      -- vault status 2>&1 || true
  )"

  # Vault returns a non-zero exit code while sealed, but a valid status
  # response still includes the Initialized and Sealed fields.
  if grep -Eq 'Initialized|Sealed' <<<"$STATUS_OUTPUT"; then
    log_info "Vault CLI is available."
    break
  fi

  if [[ "$attempt" -eq 60 ]]; then
    log_error "Vault CLI did not become available after 5 minutes."
    echo "$STATUS_OUTPUT" >&2
    exit 1
  fi

  sleep 5
done

log_info "Checking Vault initialization status..."

VAULT_STATUS_OUTPUT="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- vault status 2>&1 || true
)"

if grep -Eq 'Initialized[[:space:]]+false' <<<"$VAULT_STATUS_OUTPUT"; then
  VAULT_INITIALIZED="false"
  log_info "Vault is not initialized."
elif grep -Eq 'Initialized[[:space:]]+true' <<<"$VAULT_STATUS_OUTPUT"; then
  VAULT_INITIALIZED="true"
  log_info "Vault is already initialized."
else
  log_error "Could not determine Vault initialization status."
  echo "$VAULT_STATUS_OUTPUT" >&2
  exit 1
fi

if [[ "$VAULT_INITIALIZED" == "false" ]]; then
  log_info "Initializing Vault..."

  VAULT_INIT_JSON="$(
    "${KUBECTL[@]}" exec \
      --namespace "$VAULT_NAMESPACE" \
      "$VAULT_POD" \
      -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json
  )"

  VAULT_UNSEAL_KEY="$(jq -r '.unseal_keys_b64[0]' <<<"$VAULT_INIT_JSON")"
  VAULT_TOKEN="$(jq -r '.root_token' <<<"$VAULT_INIT_JSON")"

  if [[ -z "$VAULT_UNSEAL_KEY" || "$VAULT_UNSEAL_KEY" == "null" ]]; then
    log_error "Failed to read the Vault unseal key."
    exit 1
  fi

  if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
    log_error "Failed to read the Vault root token."
    exit 1
  fi

  cat >"$VAULT_KEYS_FILE" <<EOF
export VAULT_UNSEAL_KEY='$VAULT_UNSEAL_KEY'
export VAULT_TOKEN='$VAULT_TOKEN'
EOF

  chmod 600 "$VAULT_KEYS_FILE"

  log_info "Vault initialized."
  log_info "Vault recovery values saved locally with mode 600."
else
  if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
    log_error "Vault is initialized, but the local keys file is missing:"
    echo "        $VAULT_KEYS_FILE" >&2
    log_error "Restore the keys file or provide the recovery values."
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$VAULT_KEYS_FILE"

  : "${VAULT_UNSEAL_KEY:?VAULT_UNSEAL_KEY is missing from the Vault keys file}"
  : "${VAULT_TOKEN:?VAULT_TOKEN is missing from the Vault keys file}"

  log_info "Loaded existing Vault recovery values from the local keys file."
fi

export VAULT_UNSEAL_KEY
export VAULT_TOKEN

log_info "Checking whether Vault is sealed..."

VAULT_STATUS_OUTPUT="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- vault status 2>&1 || true
)"

if grep -Eq 'Sealed[[:space:]]+true' <<<"$VAULT_STATUS_OUTPUT"; then
  log_info "Unsealing Vault..."

  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- vault operator unseal "$VAULT_UNSEAL_KEY" \
    >/dev/null

  log_info "Vault unseal command completed."
elif grep -Eq 'Sealed[[:space:]]+false' <<<"$VAULT_STATUS_OUTPUT"; then
  log_info "Vault is already unsealed."
else
  log_error "Could not determine Vault seal status."
  echo "$VAULT_STATUS_OUTPUT" >&2
  exit 1
fi

log_info "Waiting for Vault to become active and unsealed..."

for attempt in {1..30}; do
  STATUS_OUTPUT="$(
    "${KUBECTL[@]}" exec \
      --namespace "$VAULT_NAMESPACE" \
      "$VAULT_POD" \
      -- vault status 2>&1 || true
  )"

  if grep -Eq 'Sealed[[:space:]]+false' <<<"$STATUS_OUTPUT"; then
    log_info "Vault is active and unsealed."
    break
  fi

  if [[ "$attempt" -eq 30 ]]; then
    log_error "Vault did not become active after the unseal operation."
    echo "$STATUS_OUTPUT" >&2
    exit 1
  fi

  sleep 2
done

log_info "Waiting for Vault pod readiness..."

"${KUBECTL[@]}" wait \
  --namespace "$VAULT_NAMESPACE" \
  --for=condition=Ready \
  "pod/${VAULT_POD}" \
  --timeout=5m

log_info "Vault pod is Ready."

log_info "Ensuring KV v2 secrets engine exists at kv/..."

if ! VAULT_MOUNTS_JSON="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault secrets list -format=json
)"; then
  log_error "Failed to list Vault secrets engines."
  exit 1
fi

if jq -e 'has("kv/")' <<<"$VAULT_MOUNTS_JSON" >/dev/null; then
  KV_VERSION="$(
    jq -r '."kv/".options.version // "1"' \
      <<<"$VAULT_MOUNTS_JSON"
  )"

  if [[ "$KV_VERSION" != "2" ]]; then
    log_error "A secrets engine already exists at kv/, but it is not KV v2."
    log_error "Detected KV version: $KV_VERSION"
    exit 1
  fi

  log_info "KV v2 secrets engine already exists at kv/."
else
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault secrets enable \
      -path=kv \
      kv-v2

  log_info "KV v2 secrets engine enabled at kv/."
fi

log_info "Ensuring Vault Kubernetes auth is configured..."

if ! VAULT_AUTH_JSON="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault auth list -format=json
)"; then
  log_error "Failed to list Vault authentication methods."
  exit 1
fi

if jq -e 'has("kubernetes/")' <<<"$VAULT_AUTH_JSON" >/dev/null; then
  log_info "Kubernetes auth method is already enabled."
else
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault auth enable kubernetes

  log_info "Kubernetes auth method enabled."
fi

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  sh -c '
    vault write auth/kubernetes/config \
      token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
      kubernetes_host="https://kubernetes.default.svc:443" \
      kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
      disable_iss_validation=true
  '

log_info "Vault Kubernetes auth configured."

log_info "Writing DevOps secrets to Vault..."

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/devops/dockerhub \
    username="$DOCKERHUB_USERNAME" \
    token="$DOCKERHUB_TOKEN"

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/devops/jenkins \
    username="$JENKINS_USER" \
    api_token="$JENKINS_API_TOKEN"

log_info "Writing Slack webhook to Vault..."

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/monitoring/slack \
    webhook_url="$SLACK_WEBHOOK_URL"

log_info "Slack webhook written to Vault."

log_info "Writing Make log webhook to Vault..."

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/integrations/make \
    webhook_url="$MAKE_LOG_WEBHOOK_URL"

log_info "Make log webhook written to Vault."

log_info "DevOps secrets written to Vault."

log_info "Writing application secrets to Vault..."

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/weather-app/staging/app \
    APP_ENV="staging" \
    VAULT_TEST_VALUE="hello-from-staging-vault"

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault kv put kv/weather-app/prod/app \
    APP_ENV="prod" \
    VAULT_TEST_VALUE="hello-from-prod-vault"


log_info "Ensuring Grafana admin credentials exist in Vault..."

GRAFANA_SECRET_JSON="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/monitoring/grafana \
    2>/dev/null || true
)"

if jq -e '
  .data.data.admin_user != null and
  .data.data.admin_password != null
' <<<"$GRAFANA_SECRET_JSON" >/dev/null 2>&1; then
  log_info "Grafana admin credentials already exist in Vault; preserving them."
else
  GRAFANA_ADMIN_PASSWORD="$(openssl rand -hex 24)"

  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv put kv/monitoring/grafana \
      admin_user="admin" \
      admin_password="$GRAFANA_ADMIN_PASSWORD"

  unset GRAFANA_ADMIN_PASSWORD

  log_info "Grafana admin credentials created in Vault."
fi

log_info "Application secrets written to Vault."

log_info "Ensuring n8n configuration exists in Vault..."

N8N_SECRET_JSON="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/n8n/config \
    2>/dev/null || true
)"

if jq -e '
  .data.data.N8N_ENCRYPTION_KEY != null and
  .data.data.N8N_HOST != null and
  .data.data.N8N_PORT != null and
  .data.data.N8N_PROTOCOL != null
' <<<"$N8N_SECRET_JSON" >/dev/null 2>&1; then
  log_info "n8n configuration already exists in Vault; preserving it."
else
  N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"

  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv put kv/n8n/config \
      N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
      N8N_HOST="n8n.weather-app-as.com" \
      N8N_PORT="5678" \
      N8N_PROTOCOL="https"

  unset N8N_ENCRYPTION_KEY

  log_info "n8n configuration created in Vault."
fi

unset N8N_SECRET_JSON

log_info "Writing Vault policies for application environments..."

"${KUBECTL[@]}" exec \
  --stdin \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault policy write weather-app-staging - <<'EOF'
path "kv/data/weather-app/staging/app" {
  capabilities = ["read"]
}
EOF

"${KUBECTL[@]}" exec \
  --stdin \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault policy write weather-app-prod - <<'EOF'
path "kv/data/weather-app/prod/app" {
  capabilities = ["read"]
}
EOF


"${KUBECTL[@]}" exec \
  --stdin \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault policy write grafana - <<'EOF'
path "kv/data/monitoring/grafana" {
  capabilities = ["read"]
}
EOF

log_info "Vault application policies written."

log_info "Writing Vault Kubernetes roles..."

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault write auth/kubernetes/role/weather-app-staging \
    bound_service_account_names="weather-app-staging" \
    bound_service_account_namespaces="wa-staging" \
    policies="weather-app-staging" \
    ttl="24h"

"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault write auth/kubernetes/role/weather-app-prod \
    bound_service_account_names="weather-app-prod" \
    bound_service_account_namespaces="wa-prod" \
    policies="weather-app-prod" \
    ttl="24h"


"${KUBECTL[@]}" exec \
  --namespace "$VAULT_NAMESPACE" \
  "$VAULT_POD" \
  -- env VAULT_TOKEN="$VAULT_TOKEN" \
  vault write auth/kubernetes/role/grafana \
    bound_service_account_names="grafana" \
    bound_service_account_namespaces="monitoring" \
    policies="grafana" \
    ttl="24h"

log_info "Vault Kubernetes roles written."

log_info "Performing final Vault status check..."

FINAL_STATUS="$(
  "${KUBECTL[@]}" exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- vault status 2>&1 || true
)"

if ! grep -Eq 'Initialized[[:space:]]+true' <<<"$FINAL_STATUS"; then
  log_error "Vault is not initialized after bootstrap."
  echo "$FINAL_STATUS" >&2
  exit 1
fi

if ! grep -Eq 'Sealed[[:space:]]+false' <<<"$FINAL_STATUS"; then
  log_error "Vault is still sealed after bootstrap."
  echo "$FINAL_STATUS" >&2
  exit 1
fi

log_info "Vault bootstrap completed successfully."
log_info "Vault is initialized, unsealed, configured and Ready."

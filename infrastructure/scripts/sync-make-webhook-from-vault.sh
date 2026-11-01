#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

VAULT_KEYS_FILE="${HOME}/.vault-lab/weather-app-vault.env"

if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
  echo "[ERROR] Vault keys file not found: $VAULT_KEYS_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VAULT_KEYS_FILE"

: "${VAULT_TOKEN:?VAULT_TOKEN is missing from Vault keys file}"

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

TARGET_NAMESPACE="logging"
SECRET_NAME="fluent-bit-make-webhook"

for command in kubectl jq base64; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "[ERROR] Required command is missing: $command" >&2
    exit 1
  fi
done

echo "[INFO] Reading Make webhook from Vault..."

VAULT_RESPONSE="$(
  kubectl exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/integrations/make
)"

MAKE_LOG_WEBHOOK_URL="$(
  jq -r '.data.data.webhook_url // empty' <<<"$VAULT_RESPONSE"
)"

if [[ -z "$MAKE_LOG_WEBHOOK_URL" ]]; then
  echo "[ERROR] webhook_url is missing from Vault path kv/integrations/make" >&2
  exit 1
fi

if [[ "$MAKE_LOG_WEBHOOK_URL" =~ ^https://([^/]+)(/.*)$ ]]; then
  MAKE_WEBHOOK_HOST="${BASH_REMATCH[1]}"
  MAKE_WEBHOOK_URI="${BASH_REMATCH[2]}"
else
  echo "[ERROR] Make webhook must be a valid HTTPS URL with a path" >&2
  exit 1
fi

if ! kubectl get namespace "$TARGET_NAMESPACE" >/dev/null 2>&1; then
  echo "[INFO] Creating namespace $TARGET_NAMESPACE..."

  kubectl create namespace "$TARGET_NAMESPACE"
fi

HOST_B64="$(printf '%s' "$MAKE_WEBHOOK_HOST" | base64 -w 0)"
URI_B64="$(printf '%s' "$MAKE_WEBHOOK_URI" | base64 -w 0)"

echo "[INFO] Applying Secret $SECRET_NAME in namespace $TARGET_NAMESPACE..."

kubectl apply --filename - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${TARGET_NAMESPACE}
  labels:
    app.kubernetes.io/managed-by: vault-sync
type: Opaque
data:
  MAKE_WEBHOOK_HOST: ${HOST_B64}
  MAKE_WEBHOOK_URI: ${URI_B64}
YAML

unset MAKE_LOG_WEBHOOK_URL
unset MAKE_WEBHOOK_HOST
unset MAKE_WEBHOOK_URI
unset HOST_B64
unset URI_B64
unset VAULT_RESPONSE

echo "[INFO] Make webhook Secret sync completed."

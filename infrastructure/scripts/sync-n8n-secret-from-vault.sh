#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

VAULT_KEYS_FILE="${HOME}/.vault-lab/weather-app-vault.env"
VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
TARGET_NAMESPACE="n8n"
SECRET_NAME="n8n-secrets"

if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
  echo "[ERROR] Vault keys file not found: $VAULT_KEYS_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VAULT_KEYS_FILE"

: "${VAULT_TOKEN:?VAULT_TOKEN is missing from Vault keys file}"

echo "[INFO] Waiting for Vault to become ready..."

kubectl wait \
  --namespace "$VAULT_NAMESPACE" \
  --for=condition=Ready \
  "pod/${VAULT_POD}" \
  --timeout=5m

echo "[INFO] Reading n8n configuration from Vault..."

VAULT_RESPONSE="$(
  kubectl exec \
    --namespace "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/n8n/config
)"

for required_field in \
  N8N_ENCRYPTION_KEY \
  N8N_HOST \
  N8N_PORT \
  N8N_PROTOCOL; do
  if ! jq -e --arg field "$required_field" \
    '.data.data[$field] | type == "string" and length > 0' \
    <<<"$VAULT_RESPONSE" >/dev/null; then
    echo "[ERROR] $required_field is missing from Vault path kv/n8n/config" >&2
    exit 1
  fi
done

kubectl create namespace "$TARGET_NAMESPACE" \
  --dry-run=client \
  -o yaml | kubectl apply -f - >/dev/null

echo "[INFO] Applying $SECRET_NAME in namespace $TARGET_NAMESPACE..."

jq '{
  apiVersion: "v1",
  kind: "Secret",
  metadata: {
    name: "n8n-secrets",
    namespace: "n8n"
  },
  type: "Opaque",
  stringData: {
    N8N_ENCRYPTION_KEY: .data.data.N8N_ENCRYPTION_KEY,
    N8N_HOST: .data.data.N8N_HOST,
    N8N_PORT: .data.data.N8N_PORT,
    N8N_PROTOCOL: .data.data.N8N_PROTOCOL
  }
}' <<<"$VAULT_RESPONSE" | kubectl apply -f - >/dev/null

unset VAULT_RESPONSE VAULT_TOKEN VAULT_UNSEAL_KEY

echo "[INFO] n8n Kubernetes Secret sync completed."

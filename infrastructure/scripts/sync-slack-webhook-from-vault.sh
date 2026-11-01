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

TARGET_NAMESPACE="wa-staging"
SECRET_NAME="weather-app-slack-webhook"

echo "[INFO] Reading Slack webhook from Vault..."

VAULT_RESPONSE="$(
  kubectl exec \
    -n "$VAULT_NAMESPACE" \
    "$VAULT_POD" \
    -- env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/monitoring/slack
)"

SLACK_WEBHOOK_URL="$(
  jq -r '.data.data.webhook_url // empty' <<<"$VAULT_RESPONSE"
)"

if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
  echo "[ERROR] webhook_url is missing from Vault path kv/monitoring/slack" >&2
  exit 1
fi

if ! kubectl get namespace "$TARGET_NAMESPACE" >/dev/null 2>&1; then
  echo "[ERROR] Namespace does not exist: $TARGET_NAMESPACE" >&2
  exit 1
fi

WEBHOOK_B64="$(printf '%s' "$SLACK_WEBHOOK_URL" | base64 -w 0)"

echo "[INFO] Applying Secret $SECRET_NAME in namespace $TARGET_NAMESPACE..."

cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${TARGET_NAMESPACE}
type: Opaque
data:
  url: ${WEBHOOK_B64}
YAML

unset SLACK_WEBHOOK_URL
unset WEBHOOK_B64
unset VAULT_RESPONSE

echo "[INFO] Slack webhook Secret sync completed."

#!/usr/bin/env bash
set -euo pipefail

VAULT_KEYS_FILE="${HOME}/.vault-lab/weather-app-vault.env"

if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
  echo "[ERROR] Vault keys file not found: $VAULT_KEYS_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VAULT_KEYS_FILE"

: "${VAULT_TOKEN:?VAULT_TOKEN is missing from Vault keys file}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Reading Jenkins credentials from Vault..."

VAULT_RESPONSE="$(
  kubectl exec -n vault vault-0 -- \
    env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/devops/jenkins
)"

JENKINS_USER="$(echo "$VAULT_RESPONSE" | jq -r '.data.data.username // empty')"
JENKINS_TOKEN="$(echo "$VAULT_RESPONSE" | jq -r '.data.data.api_token // empty')"

if [[ -z "$JENKINS_USER" ]]; then
  echo "[ERROR] Jenkins username missing in Vault path kv/devops/jenkins"
  exit 1
fi

if [[ -z "$JENKINS_TOKEN" ]]; then
  echo "[ERROR] Jenkins API token missing in Vault path kv/devops/jenkins"
  exit 1
fi

export JENKINS_USER
export JENKINS_TOKEN

echo "[INFO] Waiting for Jenkins to become ready..."

for attempt in {1..30}; do
  if curl -fsS \
    -u "$JENKINS_USER:$JENKINS_TOKEN" \
    "http://jenkins.weather-app-as.com/whoAmI/api/json" \
    >/dev/null 2>&1; then
    echo "[INFO] Jenkins is ready."
    break
  fi

  if [[ "$attempt" -eq 30 ]]; then
    echo "[ERROR] Jenkins did not become ready after 5 minutes." >&2
    exit 1
  fi

  echo "[INFO] Jenkins is not ready yet. Retrying in 10 seconds..."
  sleep 10
done


echo "[INFO] Running Jenkins Kubernetes bootstrap using Vault credentials..."

exec "${SCRIPT_DIR}/configure-jenkins-k8s-safe.sh"

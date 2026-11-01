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

SECRET_NAME="dockerhub-secret"
NAMESPACES=("weather-app" "wa-staging" "wa-prod")

echo "[INFO] Reading DockerHub credentials from Vault..."

VAULT_RESPONSE="$(
  kubectl exec -n vault vault-0 -- \
    env VAULT_TOKEN="$VAULT_TOKEN" \
    vault kv get -format=json kv/devops/dockerhub
)"


DOCKERHUB_USERNAME="$(echo "$VAULT_RESPONSE" | jq -r '.data.data.username')"
DOCKERHUB_TOKEN="$(echo "$VAULT_RESPONSE" | jq -r '.data.data.token')"

if [[ -z "$DOCKERHUB_USERNAME" || "$DOCKERHUB_USERNAME" == "null" ]]; then
  echo "[ERROR] DockerHub username missing in Vault path kv/devops/dockerhub"
  exit 1
fi

if [[ -z "$DOCKERHUB_TOKEN" || "$DOCKERHUB_TOKEN" == "null" ]]; then
  echo "[ERROR] DockerHub token missing in Vault path kv/devops/dockerhub"
  exit 1
fi

AUTH_B64="$(printf "%s:%s" "$DOCKERHUB_USERNAME" "$DOCKERHUB_TOKEN" | base64 -w 0)"

DOCKER_CONFIG_JSON="$(cat <<JSON
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "${DOCKERHUB_USERNAME}",
      "password": "${DOCKERHUB_TOKEN}",
      "auth": "${AUTH_B64}"
    }
  }
}
JSON
)"

DOCKER_CONFIG_B64="$(printf "%s" "$DOCKER_CONFIG_JSON" | base64 -w 0)"

for NS in "${NAMESPACES[@]}"; do
  if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
    echo "[WARN] Namespace $NS does not exist, skipping"
    continue
  fi

  echo "[INFO] Applying $SECRET_NAME in namespace $NS"

  cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NS}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${DOCKER_CONFIG_B64}
YAML
done

unset DOCKERHUB_TOKEN
unset DOCKERHUB_USERNAME
unset AUTH_B64
unset DOCKER_CONFIG_JSON
unset DOCKER_CONFIG_B64

echo "[INFO] DockerHub imagePullSecret sync completed"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AGENT_POD_YAML="${AGENT_POD_YAML:-${REPO_ROOT}/jenkins-agents/weather-ci-agent.yaml}"

: "${JENKINS_URL:?Missing JENKINS_URL}"
: "${JENKINS_USER:?Missing JENKINS_USER}"
: "${JENKINS_TOKEN:?Missing JENKINS_TOKEN}"
: "${K8S_API_URL:?Missing K8S_API_URL}"
: "${JENKINS_INTERNAL_URL:?Missing JENKINS_INTERNAL_URL}"

JENKINS_URL="${JENKINS_URL%/}"

K8S_NAMESPACE="${K8S_NAMESPACE:-jenkins}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-jenkins-token}"

CLOUD_NAME="${CLOUD_NAME:-k8s}"
TEMPLATE_NAME="${TEMPLATE_NAME:-k8s-agent}"
AGENT_LABEL="${AGENT_LABEL:-k8s-agent}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-jenkins}"
CREDENTIAL_ID="${CREDENTIAL_ID:-k8s-jenkins-token}"

for cmd in curl kubectl base64; do
  command -v "$cmd" >/dev/null || {
    echo "[ERROR] Missing command: $cmd"
    exit 1
  }
done

[[ -f "$AGENT_POD_YAML" ]] || {
  echo "[ERROR] Missing agent YAML: $AGENT_POD_YAML"
  exit 1
}

echo "[INFO] Checking Jenkins auth..."
curl -fsS -u "$JENKINS_USER:$JENKINS_TOKEN" \
  "$JENKINS_URL/whoAmI/api/json" >/dev/null

echo "[INFO] Getting Jenkins crumb..."
CRUMB="$(
  curl -fsS -u "$JENKINS_USER:$JENKINS_TOKEN" \
    "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)"
)"

echo "[INFO] Reading Kubernetes ServiceAccount token..."
K8S_TOKEN="$(
  kubectl -n "$K8S_NAMESPACE" get secret "$K8S_SECRET_NAME" \
    -o jsonpath='{.data.token}' | base64 -d
)"

b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

K8S_TOKEN_B64="$(b64 "$K8S_TOKEN")"
AGENT_YAML_B64="$(base64 < "$AGENT_POD_YAML" | tr -d '\n')"
K8S_API_URL_B64="$(b64 "$K8S_API_URL")"
JENKINS_INTERNAL_URL_B64="$(b64 "$JENKINS_INTERNAL_URL")"

echo "[INFO] Configuring Jenkins Kubernetes cloud and pod template..."

GROOVY_SCRIPT="$(cat <<EOF
import jenkins.model.Jenkins
import hudson.util.Secret

import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl

import org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud
import org.csanchez.jenkins.plugins.kubernetes.PodTemplate

def decode = { value -> new String(value.decodeBase64(), "UTF-8") }

def k8sToken = decode("${K8S_TOKEN_B64}")
def agentYaml = decode("${AGENT_YAML_B64}")
def k8sApiUrl = decode("${K8S_API_URL_B64}")
def jenkinsInternalUrl = decode("${JENKINS_INTERNAL_URL_B64}")

def cloudName = "${CLOUD_NAME}"
def templateName = "${TEMPLATE_NAME}"
def agentLabel = "${AGENT_LABEL}"
def namespace = "${K8S_NAMESPACE}"
def serviceAccount = "${SERVICE_ACCOUNT}"
def credentialId = "${CREDENTIAL_ID}"

def jenkins = Jenkins.get()
def domain = Domain.global()

def store = jenkins.getExtensionList(
  "com.cloudbees.plugins.credentials.SystemCredentialsProvider"
)[0].getStore()

def existingCredential = CredentialsProvider.lookupCredentials(
  StringCredentialsImpl.class,
  jenkins,
  null,
  null
).find { it.id == credentialId }

def credential = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  credentialId,
  "Kubernetes Jenkins ServiceAccount token",
  Secret.fromString(k8sToken)
)

if (existingCredential) {
  store.updateCredentials(domain, existingCredential, credential)
  println("Updated credential: " + credentialId)
} else {
  store.addCredentials(domain, credential)
  println("Created credential: " + credentialId)
}

def cloud = jenkins.clouds.find { it.name == cloudName }

if (!cloud) {
  cloud = new KubernetesCloud(cloudName)
  jenkins.clouds.add(cloud)
  println("Created cloud: " + cloudName)
} else {
  println("Updated cloud: " + cloudName)
}

cloud.setServerUrl(k8sApiUrl)
cloud.setSkipTlsVerify(true)
cloud.setNamespace(namespace)
cloud.setCredentialsId(credentialId)
cloud.setJenkinsUrl(jenkinsInternalUrl)
cloud.setWebSocket(true)
cloud.setContainerCapStr("10")
cloud.setConnectTimeout(10)
cloud.setReadTimeout(20)

def oldTemplate = cloud.templates.find { it.name == templateName }

if (oldTemplate) {
  cloud.templates.remove(oldTemplate)
  println("Removed old template: " + templateName)
}

def template = new PodTemplate()
template.setName(templateName)
template.setLabel(agentLabel)
template.setNamespace(namespace)
template.setServiceAccount(serviceAccount)
template.setIdleMinutes(0)
template.setYaml(agentYaml)

cloud.templates.add(template)
jenkins.save()

def savedCloud = Jenkins.get().clouds.find { it.name == cloudName }
if (!savedCloud) {
  throw new RuntimeException("Cloud was not saved: " + cloudName)
}

def savedTemplate = savedCloud.templates.find { it.name == templateName }
if (!savedTemplate) {
  throw new RuntimeException("Template was not saved: " + templateName)
}

["name: python", "name: docker", "name: dind", "name: kubectl", "DOCKER_HOST"].each {
  if (!savedTemplate.yaml.contains(it)) {
    throw new RuntimeException("Missing in pod YAML: " + it)
  }
}

println("Jenkins Kubernetes configuration OK")
println("Cloud: " + savedCloud.name)
println("Template: " + savedTemplate.name)
println("Label: " + savedTemplate.label)
EOF
)"

curl -fsS \
  -u "$JENKINS_USER:$JENKINS_TOKEN" \
  -H "$CRUMB" \
  --data-urlencode "script=${GROOVY_SCRIPT}" \
  "$JENKINS_URL/scriptText"

echo "[INFO] Jenkins Kubernetes config done."

#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME_DIR="/opt/jenkins_home"
JENKINS_IMAGE="jenkins/jenkins:lts"

echo "[INFO] Preparing Jenkins home..."
sudo mkdir -p "$JENKINS_HOME_DIR/casc_configs"

echo "[INFO] Removing old Jenkins container if exists..."
sudo docker rm -f jenkins || true

echo "[INFO] Starting Jenkins with JCasC enabled..."
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml \
  -v "$JENKINS_HOME_DIR:/var/jenkins_home" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$JENKINS_IMAGE"

echo "[INFO] Waiting for Jenkins..."
for i in $(seq 1 60); do
  if curl -fsS http://localhost:8080/login >/dev/null; then
    echo "[INFO] Jenkins is up."
    exit 0
  fi

  sleep 5
done

echo "[ERROR] Jenkins did not start."
sudo docker logs jenkins --tail=100
exit 1

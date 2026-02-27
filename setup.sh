#!/usr/bin/env bash
set -euo pipefail

############################################################
# Apex Nebula Task Setup
# Initializes broken ingress state
# Creates /grader/original_uid for validation
############################################################

NS="ingress-system"

echo "[setup] Creating namespace..."
kubectl create namespace ${NS} --dry-run=client -o yaml | kubectl apply -f -

echo "[setup] Creating broken ConfigMap..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: ${NS}
data:
  ssl-session-cache: "shared:SSL:1m"
  ssl-session-timeout: "0"
EOF

echo "[setup] Deploying ingress controller (broken state)..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ingress-controller
  template:
    metadata:
      labels:
        app: ingress-controller
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          limits:
            memory: "128Mi"
        command:
        - sh
        - -c
        - |
          echo "TLS timeout = \$SSL_SESSION_TIMEOUT"
          if [ "\$SSL_SESSION_TIMEOUT" = "0" ]; then
            echo "Simulating TLS session memory leak..."
            sleep infinity
          else
            nginx -g "daemon off;"
          fi
        env:
        - name: SSL_SESSION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              name: ingress-nginx-config
              key: ssl-session-timeout
EOF

sleep 5

############################################################
# Save ORIGINAL UID for grader validation
############################################################

mkdir -p /grader

ORIGINAL_UID=$(kubectl get deployment ingress-controller \
  -n ${NS} \
  -o jsonpath='{.metadata.uid}')

echo "${ORIGINAL_UID}" > /grader/original_uid
chmod 400 /grader/original_uid

echo "[setup] Saved original UID to /grader/original_uid"
echo "[setup] Setup complete."
#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Ingress TLS Memory Leak — Setup"
echo "=========================================="

NAMESPACE=ingress-system

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

############################################
# Broken NGINX ConfigMap (TLS leak)
############################################

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NAMESPACE
data:
  ssl-session-cache: "shared:SSL:1m"
  ssl-session-timeout: "0"   # BROKEN: never expires
EOF

############################################
# Ingress Controller Deployment
############################################

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: $NAMESPACE
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
          requests:
            memory: "128Mi"
        env:
        - name: SSL_SESSION_CACHE
          valueFrom:
            configMapKeyRef:
              name: ingress-nginx-config
              key: ssl-session-cache
        - name: SSL_SESSION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              name: ingress-nginx-config
              key: ssl-session-timeout
        command:
        - /bin/sh
        - -c
        - |
          if [ "$SSL_SESSION_TIMEOUT" = "0" ]; then
            echo "Simulating memory leak..."
            tail -f /dev/null
          else
            nginx -g 'daemon off;'
          fi
EOF

############################################
# Save UID for anti-cheat
############################################

UID=$(kubectl get deployment ingress-controller \
  -n $NAMESPACE -o jsonpath='{.metadata.uid}')

mkdir -p /grader
echo "$UID" > /grader/original-uid

echo "Setup complete."
#!/usr/bin/env bash
set -euo pipefail

NS=ingress-system

echo "Initializing ingress TLS memory leak scenario..."

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

##################################################
# Broken TLS configuration (ROOT CAUSE)
##################################################

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  ssl-session-cache: "shared:SSL:1m"
  ssl-session-timeout: "0"
EOF

##################################################
# Ingress Controller Deployment
##################################################

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: $NS
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

##################################################
# REQUIRED BY GRADER
# Save original Deployment UID
##################################################

echo "Saving deployment UID for grader validation..."

mkdir -p /grader

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' \
  > /grader/original_uid

echo "Setup complete."
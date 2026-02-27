#!/usr/bin/env bash
set -euo pipefail

NS=ingress-system

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

############################################
# Broken ConfigMap
############################################
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

############################################
# Deployment
############################################
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
        command:
        - sh
        - -c
        - |
          if [ "\$SSL_SESSION_TIMEOUT" = "0" ]; then
            echo "Simulating memory leak..."
            sleep infinity
          else
            nginx -g 'daemon off;'
          fi
        env:
        - name: SSL_SESSION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              name: ingress-nginx-config
              key: ssl-session-timeout
EOF

############################################
# Save ORIGINAL UID (ANTI-CHEAT)
############################################
UID=$(kubectl get deployment ingress-controller -n $NS -o jsonpath='{.metadata.uid}')

mkdir -p /grader
echo "$UID" > /grader/original_uid
chmod 400 /grader/original_uid
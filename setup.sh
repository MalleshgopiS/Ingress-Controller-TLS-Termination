#!/bin/bash
set -e

# ==========================================================
# Nebula Hard++ Setup Script
# Task: ingress-controller-tls-termination-hardpp
#
# This script:
#   1. Creates ConfigMap with INVALID ssl_session_timeout
#   2. Creates Deployment (3 replicas, maxUnavailable=0)
#   3. Mounts nginx.conf correctly
#   4. Creates Service
#   5. Saves original Deployment UID to /grader/original_uid
#
# IMPORTANT:
#   This script must produce a WORKING nginx setup
#   except for the invalid ssl_session_timeout value.
# ==========================================================

NS="default"

echo "Creating ConfigMap..."

kubectl create configmap ingress-nginx-config \
  -n $NS \
  --from-literal=nginx.conf='
events {}

http {
  server {
    listen 8080;

    ssl_session_timeout 0m;

    location / {
      return 200 "healthy";
    }
  }
}
'

echo "Creating Deployment..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: $NS
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
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
        image: nginx:1.25.3
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: 128Mi
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
EOF

echo "Creating Service..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
  namespace: $NS
spec:
  selector:
    app: ingress-controller
  ports:
  - port: 80
    targetPort: 8080
EOF

echo "Waiting for rollout..."

kubectl rollout status deployment/ingress-controller -n $NS --timeout=300s

echo "Saving original UID..."

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup completed successfully."
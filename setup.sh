#!/bin/bash
# ==========================================================
# Hard++ Setup Script
# ==========================================================
#
# Creates initial broken state:
# - Namespace ingress-system
# - ConfigMap with invalid ssl_session_timeout 0;
# - Deployment with 3 replicas (nginx:1.25.3)
# - Service exposing nginx
#
# Saves original Deployment UID to:
#   /grader/original_uid
#
# nginx returns HTTP 200 for validation.
# ==========================================================

set -e

NS="ingress-system"

kubectl create namespace $NS 2>/dev/null || true

# Create ConfigMap with INVALID timeout
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  nginx.conf: |
    worker_processes auto;
    events {
        worker_connections 1024;
    }
    http {
        include /etc/nginx/mime.types;
        server {
            listen 80;
            ssl_session_timeout 0;
            location / {
                return 200 "OK";
            }
        }
    }
EOF

# Create Service
cat <<EOF | kubectl apply -f -
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
      targetPort: 80
EOF

# Create Deployment
cat <<EOF | kubectl apply -f -
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
      maxSurge: 1
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
            - containerPort: 80
          resources:
            limits:
              memory: "128Mi"
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: nginx-config
          configMap:
            name: ingress-nginx-config
EOF

kubectl rollout status deployment/ingress-controller -n $NS --timeout=240s

# Store original UID for grader validation
mkdir -p /grader
kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
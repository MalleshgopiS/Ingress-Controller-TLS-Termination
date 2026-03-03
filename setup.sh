#!/bin/bash
# ==========================================================
# Hard++ Setup Script (Nebula Stable Version)
# ==========================================================
#
# Environment: Nebula k3s (snapshot mode)
#
# Creates:
# - Namespace: ingress-system
# - RBAC role for ubuntu user
# - ConfigMap: ingress-nginx-config
# - Service: ingress-controller
# - Deployment: ingress-controller
#
# Deployment Properties:
#   - replicas: 3
#   - strategy: RollingUpdate (maxUnavailable=0)
#   - image: nginx:1.25.3
#   - memory limit: 128Mi
#
# nginx misconfiguration:
#   ssl_session_timeout 0;
#
# Saves original Deployment UID to:
#   /grader/original_uid
#
# ==========================================================

set -e

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS 2>/dev/null || true

echo "Creating RBAC role..."
kubectl create role ubuntu-user-admin \
  --verb="*" \
  --resource="*" \
  -n $NS 2>/dev/null || true

kubectl create rolebinding ubuntu-user-admin-binding \
  --role=ubuntu-user-admin \
  --user=ubuntu \
  -n $NS 2>/dev/null || true

echo "Creating ConfigMap with stable nginx configuration..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  nginx.conf: |
    worker_processes auto;
    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;

        sendfile        on;
        keepalive_timeout  65;

        server {
            listen 80;

            ssl_session_timeout 0;

            location / {
                return 200 "OK";
            }
        }
    }
EOF

echo "Creating Service..."

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

echo "Creating Deployment..."

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

echo "Waiting for Deployment rollout..."

kubectl rollout status deployment/ingress-controller \
  -n $NS \
  --timeout=240s

echo "Saving original Deployment UID..."

kubectl get deployment ingress-controller \
  -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Hard++ Setup complete."
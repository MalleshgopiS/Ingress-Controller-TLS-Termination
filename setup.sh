#!/bin/bash
# ==========================================================
# Hard++ Task Setup Script
# ==========================================================
#
# This script prepares the initial broken environment for:
#   ingress-controller-tls-termination-hardpp
#
# It creates:
#   - Namespace: ingress-system
#   - ConfigMap: ingress-nginx-config (key: nginx.conf)
#   - Deployment: ingress-controller (3 replicas)
#   - Service: ingress-controller
#
# ----------------------------------------------------------
# ⚠ GRADER DEPENDENCY
# ----------------------------------------------------------
# The grader verifies that the Deployment is NOT deleted
# or recreated by comparing Deployment UID values.
#
# This script stores the original Deployment UID at:
#     /grader/original_uid
#
# If this file is missing, grading will fail.
# ----------------------------------------------------------
#
# nginx is configured to return HTTP 200 "OK"
# so the grader can validate service availability.
#
# ==========================================================

set -e

NS="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Creating namespace..."
kubectl create namespace $NS 2>/dev/null || true

echo "Creating ConfigMap with invalid ssl_session_timeout..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CONFIGMAP
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

            # ❌ Invalid value (must be fixed by agent)
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
  name: $DEPLOYMENT
  namespace: $NS
spec:
  selector:
    app: $DEPLOYMENT
  ports:
    - port: 80
      targetPort: 80
EOF

echo "Creating Deployment (3 replicas, maxUnavailable=0)..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
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
      app: $DEPLOYMENT
  template:
    metadata:
      labels:
        app: $DEPLOYMENT
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
            name: $CONFIGMAP
EOF

echo "Waiting for deployment rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NS --timeout=240s

echo "Saving original Deployment UID for grader..."

mkdir -p /grader

kubectl get deployment $DEPLOYMENT -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

# ----------------------------------------------------------
# Validate UID file exists (required for grader)
# ----------------------------------------------------------
if [ ! -f /grader/original_uid ]; then
  echo "FATAL: original_uid file not created!"
  exit 1
fi

echo "Setup completed successfully."
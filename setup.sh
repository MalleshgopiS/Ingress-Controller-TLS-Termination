#!/bin/bash
# ==========================================================
# Hard++ Setup Script (Nebula Quality Approved)
# ==========================================================
#
# Creates:
# - Namespace: ingress-system
# - RBAC role for ubuntu user
# - ConfigMap with invalid ssl_session_timeout
# - Service
# - Deployment with:
#     replicas: 3
#     RollingUpdate maxUnavailable=0
#     nginx:1.25.3
#     memory limit: 128Mi
#
# Saves original Deployment UID for validation.
#
# ==========================================================

set -e

NS="ingress-system"

kubectl create namespace $NS || true

kubectl create role ubuntu-user-admin \
  --verb="*" \
  --resource="*" \
  -n $NS || true

kubectl create rolebinding ubuntu-user-admin-binding \
  --role=ubuntu-user-admin \
  --user=ubuntu \
  -n $NS || true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 80;
        ssl_session_timeout 0;
        location / {
          return 200 "OK\n";
        }
      }
    }
EOF

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

kubectl rollout status deployment/ingress-controller -n $NS --timeout=180s

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Hard++ Setup complete."
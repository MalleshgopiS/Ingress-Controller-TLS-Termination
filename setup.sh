#!/bin/bash
set -e

# ==========================================================
# Nebula Hard++ Task Setup
# ----------------------------------------------------------
# Creates:
#   - ConfigMap: ingress-nginx-config
#   - Deployment: ingress-controller (3 replicas)
#   - Service: ingress-controller
#
# Intentional Misconfiguration:
#     ssl_session_timeout 0s;
#
# Why 0s?
# - Syntactically valid (nginx will start)
# - Fails required regex:
#       ^[1-9][0-9]*(s|m|h|d)$
#
# Agent must:
# - Modify ONLY ssl_session_timeout
# - Preserve Deployment UID
# - Preserve replicas=3
# - Preserve maxUnavailable=0
# - Preserve memory=128Mi
# - Preserve image=nginx:1.25.3
# - Ensure Service returns HTTP 200
#
# IMPORTANT:
# nginx MUST run in foreground (daemon off;)
# or rollout will timeout.
# ==========================================================

NS="default"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Creating ConfigMap..."

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CM
data:
  nginx.conf: |
    daemon off;

    events {}

    http {
        ssl_session_timeout 0s;

        server {
            listen 8080;

            location / {
                return 200 "healthy";
            }
        }
    }
EOF

echo "Creating Deployment..."

kubectl apply -n $NS -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
  selector:
    matchLabels:
      app: $DEPLOY
  template:
    metadata:
      labels:
        app: $DEPLOY
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.3
        resources:
          limits:
            memory: 128Mi
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: $CM
EOF

echo "Creating Service..."

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $DEPLOY
spec:
  selector:
    app: $DEPLOY
  ports:
  - port: 80
    targetPort: 8080
EOF

echo "Waiting for rollout..."

kubectl rollout status deployment/$DEPLOY -n $NS --timeout=300s

echo "Saving original Deployment UID..."

kubectl get deployment $DEPLOY -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
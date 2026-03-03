#!/bin/bash
set -e

# ==========================================================
# Nebula Hard++ Task Setup
# ----------------------------------------------------------
# This setup creates:
#   - Deployment: ingress-controller
#   - Service: ingress-controller
#   - ConfigMap: ingress-nginx-config
#
# The nginx config intentionally contains:
#     ssl_session_timeout 0s;
#
# NOTE:
# - 0s is syntactically valid (nginx must start successfully)
# - BUT it violates the required regex:
#       ^[1-9][0-9]*(s|m|h|d)$
# - Therefore the agent must update it to a valid non-zero duration.
#
# IMPORTANT:
# - Deployment UID must remain unchanged
# - Replicas = 3
# - maxUnavailable = 0
# - Memory = 128Mi
# - Image = nginx:1.25.3
# ==========================================================

NS="default"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CM
data:
  custom.conf: |
    server {
        listen 8080;
        ssl_session_timeout 0s;
        location / {
            return 200 "healthy";
        }
    }
EOF

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
          initialDelaySeconds: 2
          periodSeconds: 3
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/custom.conf
          subPath: custom.conf
      volumes:
      - name: config
        configMap:
          name: $CM
EOF

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

kubectl rollout status deployment/$DEPLOY -n $NS --timeout=300s

kubectl get deployment $DEPLOY -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid
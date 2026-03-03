#!/bin/bash
# ============================================================
# setup.sh
#
# Task: Ingress-Controller-TLS-Termination
#
# Purpose:
#   - Prepare Kubernetes environment for evaluation
#   - Create namespace, ConfigMap, Deployment, and Service
#   - Ensure Deployment becomes Available
#   - Store original Deployment UID for grader validation
#
# Requirements:
#   - Deployment image must be: nginx:1.25.3
#   - Memory limit must be: 128Mi
#   - ConfigMap must contain ssl-session-timeout="0"
#   - Deployment UID must be preserved during solution
#
# Notes:
#   - ConfigMap is intentionally NOT mounted (task focuses on config update,
#     not nginx config wiring)
#   - Readiness probe added to guarantee rollout success
#   - Script is idempotent (safe to re-run)
# ============================================================

set -euo pipefail

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "🚀 Setting up task environment..."

# ------------------------------------------------------------
# 1️⃣ Create Namespace
# ------------------------------------------------------------
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ------------------------------------------------------------
# 2️⃣ Create ConfigMap (invalid initial value)
# ------------------------------------------------------------
kubectl create configmap "$CONFIGMAP" \
  -n "$NAMESPACE" \
  --from-literal=ssl-session-timeout="0" \
  --dry-run=client -o yaml | kubectl apply -f -

# ------------------------------------------------------------
# 3️⃣ Create Deployment
# ------------------------------------------------------------
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
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
        image: nginx:1.25.3
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
          limits:
            memory: "128Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
          failureThreshold: 6
EOF

# ------------------------------------------------------------
# 4️⃣ Create Service
# ------------------------------------------------------------
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $DEPLOYMENT
  namespace: $NAMESPACE
spec:
  selector:
    app: ingress-controller
  ports:
    - port: 80
      targetPort: 80
EOF

# ------------------------------------------------------------
# 5️⃣ Wait for Deployment Availability
# ------------------------------------------------------------
echo "⏳ Waiting for Deployment rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=180s

# Extra safety wait to avoid race condition
kubectl wait --for=condition=available deployment/$DEPLOYMENT \
  -n $NAMESPACE --timeout=180s

# ------------------------------------------------------------
# 6️⃣ Store Original UID for Grader
# ------------------------------------------------------------
echo "💾 Storing original Deployment UID..."
mkdir -p /grader
kubectl get deployment $DEPLOYMENT -n $NAMESPACE \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup completed successfully."
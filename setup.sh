#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOYMENT="ingress-controller"

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

# --------------------------------------------------
# ConfigMap (grader reads this value only)
# --------------------------------------------------
kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

# --------------------------------------------------
# Deployment (NO nginx config injection)
# --------------------------------------------------
kubectl apply -n $NS -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
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
          limits:
            memory: "128Mi"
EOF

# --------------------------------------------------
# Service
# --------------------------------------------------
kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
spec:
  selector:
    app: ingress-controller
  ports:
  - port: 80
    targetPort: 80
EOF

# --------------------------------------------------
# Wait for Ready
# --------------------------------------------------
kubectl rollout status deployment/$DEPLOYMENT -n $NS --timeout=180s

# --------------------------------------------------
# Store ORIGINAL UID
# --------------------------------------------------
kubectl get deploy $DEPLOYMENT -n $NS \
  -o jsonpath='{.metadata.uid}' > /tmp/original_uid
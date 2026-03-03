#!/bin/bash
# ============================================================
# setup.sh
# Creates initial Kubernetes state (Nebula compatible)
# DO NOT block on rollout
# ============================================================

set -e

NAMESPACE="default"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

kubectl create configmap $CONFIGMAP \
  -n $NAMESPACE \
  --from-literal=ssl-session-timeout="0" \
  --dry-run=client -o yaml | kubectl apply -f -

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
          limits:
            memory: "128Mi"
          requests:
            memory: "128Mi"
EOF

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

# Create secure grader directory
mkdir -p /grader
chmod 700 /grader

# Capture original UID immediately (do not wait for availability)
kubectl get deployment $DEPLOYMENT -n $NAMESPACE \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 400 /grader/original_uid
#!/bin/bash
# ============================================================
# setup.sh
# Creates initial Kubernetes state safely in default namespace
# ============================================================

set -e

NAMESPACE="default"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

# Create ConfigMap with invalid timeout
kubectl create configmap $CONFIGMAP \
  -n $NAMESPACE \
  --from-literal=ssl-session-timeout="0" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Deployment
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

# Create Service
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

# Wait for Deployment to be ready
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=180s

# Secure grader directory
mkdir -p /grader
chmod 700 /grader

kubectl get deployment $DEPLOYMENT -n $NAMESPACE \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 400 /grader/original_uid
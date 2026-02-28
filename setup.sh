#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

echo "Creating broken ConfigMap..."

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

echo "Creating deployment..."

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
        image: nginx:1.25
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
EOF

echo "Waiting for pod..."

kubectl wait --for=condition=available deployment/ingress-controller \
  -n $NS --timeout=180s || true

# Fallback wait (more reliable in Nebula)
sleep 15

echo "Saving original UID..."

mkdir -p /grader

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."
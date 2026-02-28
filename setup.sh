#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

echo "Creating ConfigMap..."
kubectl -n $NS apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CM
data:
  ssl-session-timeout: "0"
EOF

echo "Creating Deployment..."
kubectl -n $NS apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
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
        resources:
          limits:
            memory: "128Mi"
        ports:
        - containerPort: 80
EOF

echo "Waiting for deployment rollout..."
kubectl -n $NS rollout status deployment $DEPLOY --timeout=180s

echo "Installing curl inside nginx container (required for grader)..."

POD=$(kubectl -n $NS get pods -l app=ingress-controller -o jsonpath='{.items[0].metadata.name}')

kubectl -n $NS exec "$POD" -- bash -c "
apt-get update &&
apt-get install -y curl &&
rm -rf /var/lib/apt/lists/*
"

echo "Recording original deployment UID..."
kubectl -n $NS get deploy $DEPLOY -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
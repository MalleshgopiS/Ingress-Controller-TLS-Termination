#!/bin/bash
set -e

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS 2>/dev/null || true

echo "Creating broken ConfigMap..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  ssl-session-timeout: "0"
EOF

echo "Creating deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: $NS
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
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
          requests:
            memory: "128Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
EOF

echo "Waiting for deployment rollout..."
kubectl rollout status deployment ingress-controller -n $NS --timeout=180s

echo "Saving original Deployment UID..."
kubectl get deployment ingress-controller -n $NS -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
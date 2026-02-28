#!/bin/bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Creating namespace..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Creating broken ConfigMap..."
kubectl create configmap "$CM" \
  -n "$NS" \
  --from-literal=ssl-session-timeout="0" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating deployment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOY}
  namespace: ${NS}
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
EOF

echo "Waiting for deployment rollout..."
kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=180s

echo "Saving original Deployment UID..."
DEPLOYMENT_UID=$(kubectl get deployment ${DEPLOY} -n ${NS} -o jsonpath='{.metadata.uid}')

mkdir -p /grader
echo "${DEPLOYMENT_UID}" > /grader/original_uid

echo "Setup complete."
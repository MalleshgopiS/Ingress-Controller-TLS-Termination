#!/bin/bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Creating namespace..."
kubectl create namespace ${NS} --dry-run=client -o yaml | kubectl apply -f -

echo "Creating broken ConfigMap..."
kubectl create configmap ${CM} \
  -n ${NS} \
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

      # ✅ ADD THIS INIT CONTAINER (curl installer)
      initContainers:
      - name: install-curl
        image: debian:stable-slim
        command:
          - sh
          - -c
          - |
            apt-get update &&
            apt-get install -y curl &&
            cp /usr/bin/curl /shared/curl
        volumeMounts:
        - name: shared-bin
          mountPath: /shared

      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
        volumeMounts:
        - name: shared-bin
          mountPath: /usr/local/bin

      volumes:
      - name: shared-bin
        emptyDir: {}
EOF

echo "Waiting for pod Running..."

kubectl wait --for=condition=available \
  deployment/${DEPLOY} -n ${NS} --timeout=180s

echo "Saving original UID..."

UID_VALUE=$(kubectl get deployment ${DEPLOY} -n ${NS} \
            -o jsonpath='{.metadata.uid}')

mkdir -p /grader
echo "${UID_VALUE}" > /grader/original_uid

echo "Setup complete."


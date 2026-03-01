#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS || true

echo "Granting ubuntu-user access..."
kubectl create role ubuntu-user-admin \
  --verb="*" --resource="*" -n $NS || true

kubectl create rolebinding ubuntu-user-admin-binding \
  --role=ubuntu-user-admin \
  --user=ubuntu-user -n $NS || true


echo "Creating broken ConfigMap..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: $NS
data:
  ssl-session-timeout: "0"
EOF


echo "Creating service..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
  namespace: $NS
spec:
  selector:
    app: ingress-controller
  ports:
  - port: 80
    targetPort: 80
EOF


echo "Creating deployment..."

kubectl apply -f - <<EOF
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
        image: nginx:1.25.3
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: "128Mi"
          requests:
            memory: "128Mi"
        ports:
        - containerPort: 80
EOF


echo "Waiting for pod..."

kubectl wait --for=condition=Ready pod \
  -l app=ingress-controller -n $NS --timeout=180s


echo "Saving original UID..."

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
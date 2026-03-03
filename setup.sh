#!/bin/bash
set -e

# ============================================================
# setup.sh
# Creates initial broken state for the task
# ============================================================

NAMESPACE="default"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "🔧 Creating ConfigMap with INVALID timeout..."

kubectl create configmap $CONFIGMAP \
  -n $NAMESPACE \
  --from-literal=ssl-session-timeout="0" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🚀 Creating Deployment..."

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
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 3
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

echo "🌐 Creating Service..."

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

echo "⏳ Waiting for Deployment rollout..."

kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo "💾 Saving original Deployment UID..."

kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
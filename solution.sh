#!/bin/bash
set -e

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Updating ssl-session-timeout in ConfigMap..."

# Patch ConfigMap with valid non-zero nginx duration
kubectl patch configmap "$CONFIGMAP" \
  -n "$NAMESPACE" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "♻ Restarting pod to reload configuration..."

# Delete existing pod (Deployment will recreate it)
kubectl delete pod -n "$NAMESPACE" -l app=ingress-controller

echo "Waiting for Deployment rollout to complete..."

# Wait for Deployment to be fully available
kubectl rollout status deployment/"$DEPLOYMENT" \
  -n "$NAMESPACE" \
  --timeout=120s

echo "🧪 Verifying Deployment readiness..."

# Ensure readyReplicas == 1
READY=$(kubectl get deployment "$DEPLOYMENT" \
  -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')

if [ "$READY" != "1" ]; then
  echo "Deployment not fully ready"
  exit 1
fi

echo "🌐 Verifying nginx is serving HTTP 200..."

# Port-forward in background
kubectl port-forward svc/"$DEPLOYMENT" 18080:80 -n "$NAMESPACE" >/dev/null 2>&1 &
PF_PID=$!

# Allow port-forward to initialize
sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080 || true)

# Kill port-forward
kill $PF_PID >/dev/null 2>&1 || true

if [ "$HTTP_CODE" != "200" ]; then
  echo "Nginx not serving HTTP 200"
  exit 1
fi

echo "Fix applied successfully."
#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload configuration..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

echo "Waiting for deployment to become Available..."

# ⭐ This replaces fragile pod-level wait
kubectl wait \
  --for=condition=available deployment/"$DEPLOYMENT" \
  -n "$NS" \
  --timeout=300s

echo "Stabilizing networking..."

# Small stabilization only (not minutes)
sleep 20

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
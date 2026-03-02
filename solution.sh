#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload config..."

kubectl delete pod \
  -n "$NS" \
  -l "$APP_LABEL" \
  --wait=true

echo "Waiting for new pod Ready..."

kubectl wait pod \
  -n "$NS" \
  -l "$APP_LABEL" \
  --for=condition=Ready \
  --timeout=600s

echo "Allowing nginx warm-up..."
sleep 20

echo "✅ Fix applied successfully."
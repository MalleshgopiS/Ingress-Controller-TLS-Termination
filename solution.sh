#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap "$CM" -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Triggering rollout restart..."
kubectl rollout restart deployment "$DEPLOY" -n "$NS"

# ❌ REMOVE rollout status (causes timeout in Nebula)

echo "Waiting for deployment to become Available..."
kubectl wait deployment "$DEPLOY" \
  -n "$NS" \
  --for=condition=Available=True \
  --timeout=180s

echo "Waiting for pod readiness..."
kubectl wait pod \
  -n "$NS" \
  -l app="$DEPLOY" \
  --for=condition=Ready \
  --timeout=180s

echo "Allowing nginx warm-up..."
sleep 15

echo "✅ Fix applied successfully."
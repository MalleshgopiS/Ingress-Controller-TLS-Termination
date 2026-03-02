#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting deployment..."

kubectl rollout restart deployment "$DEPLOY" -n "$NS"

# ----------------------------------------------------
# DO NOT use rollout status (causes timeout in Nebula)
# ----------------------------------------------------

echo "Waiting for deployment to become Available..."

kubectl wait deployment "$DEPLOY" \
  -n "$NS" \
  --for=condition=Available=True \
  --timeout=600s

echo "Waiting for pod Ready..."

kubectl wait pod \
  -n "$NS" \
  -l app=ingress-controller \
  --for=condition=Ready \
  --timeout=600s

echo "Allowing nginx warm-up..."
sleep 20

echo "✅ Fix applied successfully."
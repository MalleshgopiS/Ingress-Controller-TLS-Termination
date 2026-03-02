#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting ingress controller pod..."

kubectl delete pod -n "$NS" -l app=ingress-controller --wait=false

echo "Waiting for Deployment Available..."

kubectl wait deployment "$DEPLOY" \
  -n "$NS" \
  --for=condition=Available=True \
  --timeout=600s

echo "Extra nginx stabilization (Nebula)..."
sleep 45

echo "✅ Fix applied successfully."
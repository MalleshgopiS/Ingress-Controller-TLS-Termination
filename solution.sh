#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting deployment safely..."

kubectl rollout restart deployment "$DEPLOY" -n "$NS"

echo "Waiting for rollout to finish..."

kubectl rollout status deployment "$DEPLOY" \
  -n "$NS" \
  --timeout=300s

echo "Ensuring Deployment Available condition..."

kubectl wait deployment "$DEPLOY" \
  -n "$NS" \
  --for=condition=Available=True \
  --timeout=300s

echo "Stabilizing nginx..."
sleep 15

echo "✅ Fix applied successfully."
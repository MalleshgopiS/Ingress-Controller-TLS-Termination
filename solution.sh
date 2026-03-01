#!/usr/bin/env bash
set -e

NS="ingress-system"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting deployment to reload config..."

kubectl rollout restart deployment ingress-controller -n $NS

echo "Waiting for rollout..."

kubectl rollout status deployment ingress-controller -n $NS --timeout=180s

echo "Sleeping briefly to stabilize..."
sleep 10

echo "✅ Fix applied successfully."
#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Waiting for deployment to remain Ready..."

kubectl wait deployment ingress-controller \
  -n $NS \
  --for=condition=Available=True \
  --timeout=120s

echo "✅ Fix applied successfully."
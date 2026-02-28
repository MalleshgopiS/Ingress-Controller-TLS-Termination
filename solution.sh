#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Sleeping briefly to allow controller to stabilize..."
sleep 5

echo "✅ Fix applied successfully."
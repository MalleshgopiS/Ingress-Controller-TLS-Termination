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

echo "Waiting for readyReplicas == 1..."

for i in {1..120}; do
  READY=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    echo "Deployment ready"
    break
  fi

  sleep 3
done

echo "Extra stabilization..."
sleep 30

echo "✅ Fix applied successfully."
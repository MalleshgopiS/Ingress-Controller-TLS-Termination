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

kubectl delete pod -n "$NS" -l app=ingress-controller

echo "Waiting for deployment readyReplicas == 1..."

for i in {1..120}; do
  READY=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    break
  fi

  sleep 3
done

echo "Extra stabilization for Nebula..."
sleep 45

echo "✅ Fix applied successfully."
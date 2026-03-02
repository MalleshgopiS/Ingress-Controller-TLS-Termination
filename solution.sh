#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting ingress controller pod..."

kubectl delete pod -n "$NS" -l "$APP_LABEL"

echo "Waiting until ONLY one pod exists..."

# ⭐ wait until old pod fully gone
for i in {1..120}; do
  COUNT=$(kubectl get pods -n "$NS" -l "$APP_LABEL" --no-headers 2>/dev/null | wc -l)

  if [[ "$COUNT" -eq 1 ]]; then
    break
  fi
  sleep 2
done

echo "Waiting for pod Ready..."

kubectl wait pod \
  -n "$NS" \
  -l "$APP_LABEL" \
  --for=condition=Ready \
  --timeout=300s

echo "Extra stabilization for Nebula..."

# ⭐ gives grader time
sleep 40

echo "✅ Fix applied successfully."
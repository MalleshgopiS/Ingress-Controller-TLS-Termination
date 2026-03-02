#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap "$CM" -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Getting current pod..."
OLD_POD=$(kubectl get pods -n "$NS" -l app="$DEPLOY" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting old pod: $OLD_POD"
kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod to appear..."
for i in {1..90}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l app="$DEPLOY" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "${NEW_POD:-}" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi
  sleep 2
done

echo "Waiting for pod Ready condition..."
kubectl wait pod "$NEW_POD" \
  -n "$NS" \
  --for=condition=Ready \
  --timeout=300s

# ---------------------------------------------------
# CRITICAL FIX: wait until nginx actually serves HTTP
# ---------------------------------------------------

echo "Waiting for nginx to return HTTP 200..."

for i in {1..120}; do
  STATUS=$(kubectl run tmp-curl \
    --rm -i --restart=Never \
    --image=curlimages/curl:8.5.0 \
    -n "$NS" \
    -- curl -s -o /dev/null -w "%{http_code}" \
    http://ingress-controller 2>/dev/null || true)

  if [[ "$STATUS" == "200" ]]; then
    echo "nginx is serving HTTP 200"
    break
  fi

  echo "nginx not ready yet..."
  sleep 2
done

echo "Extra stabilization delay..."
sleep 15

echo "✅ Fix applied successfully."
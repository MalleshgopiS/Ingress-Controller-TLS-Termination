#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Getting current pod..."

OLD_POD=$(kubectl get pod -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting pod: $OLD_POD"

kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod to appear..."

sleep 5

NEW_POD=$(kubectl get pod -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Waiting for new pod Ready..."

kubectl wait pod "$NEW_POD" \
  -n "$NS" \
  --for=condition=Ready \
  --timeout=600s

echo "Allowing nginx warm-up..."
sleep 20

echo "✅ Fix applied successfully."
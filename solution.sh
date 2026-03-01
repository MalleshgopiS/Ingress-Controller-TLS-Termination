#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Finding old pod..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting pod $OLD_POD"
kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod..."

kubectl wait --for=condition=Ready pod \
  -l "$APP_LABEL" -n "$NS" --timeout=180s

echo "✅ Fix applied."
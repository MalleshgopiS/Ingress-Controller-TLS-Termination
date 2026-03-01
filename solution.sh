#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'


echo "Finding current pod..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting pod: $OLD_POD"
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false


echo "Waiting for replacement pod..."

kubectl wait --for=condition=Ready pod \
  -l "$APP_LABEL" -n "$NS" --timeout=180s


echo "Stabilizing..."
sleep 20

kubectl get pods -n "$NS"

echo "✅ TLS session timeout fixed successfully."
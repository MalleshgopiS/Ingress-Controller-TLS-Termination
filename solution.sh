#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload configuration..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod to be created..."

kubectl wait --for=condition=Ready pod \
  -l "$APP_LABEL" -n "$NS" --timeout=180s

echo "Waiting for deployment rollout..."

kubectl rollout status deployment/$DEPLOYMENT \
  -n "$NS" --timeout=180s

echo "Extra stabilization (nginx warmup)..."
sleep 25

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
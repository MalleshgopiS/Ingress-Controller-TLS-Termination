#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Fixing TLS session timeout..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Reloading configuration by restarting pod..."

OLD_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n $NS --wait=false

echo "Waiting for new pod..."

kubectl wait \
  --for=condition=Ready \
  pod \
  -l $APP_LABEL \
  -n $NS \
  --timeout=180s

echo "Stabilizing..."

sleep 20

echo "✅ TLS session timeout fixed successfully."
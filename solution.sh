#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Fixing ssl_session_timeout..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"default.conf":"server {\n  listen 80;\n  location / {\n    return 200 \"OK\";\n  }\n  ssl_session_timeout 10m;\n}"}}'

echo "Restarting pod to reload config..."

kubectl delete pod -n "$NS" -l app=ingress-controller

kubectl wait pod \
  -n "$NS" \
  -l app=ingress-controller \
  --for=condition=Ready \
  --timeout=300s

echo "Allowing nginx warm-up..."
sleep 20

echo "✅ Fix applied successfully."
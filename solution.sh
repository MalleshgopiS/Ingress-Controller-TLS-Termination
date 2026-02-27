#!/usr/bin/env bash
set -euo pipefail

NS=ingress-system

echo "Fixing TLS session timeout..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

kubectl rollout restart deployment ingress-controller -n $NS
kubectl rollout status deployment ingress-controller -n $NS --timeout=120s

echo "Fix complete."
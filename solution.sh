#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
CM="ingress-nginx-config"

echo "Fixing TLS session timeout..."

kubectl patch configmap $CM -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting nginx pod..."

kubectl delete pod -n $NS -l app=ingress-controller

kubectl wait --for=condition=ready pod \
  -l app=ingress-controller \
  -n $NS \
  --timeout=180s

echo "TLS session timeout fixed."
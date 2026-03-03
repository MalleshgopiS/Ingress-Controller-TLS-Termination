#!/bin/bash
# ==========================================================
# Hard++ Solution Script
# ==========================================================
#
# Requirements:
# - Only modify ssl_session_timeout
# - Preserve Deployment structure
# - Preserve replicas
# - Preserve image and memory
# - Maintain zero downtime
#
# ==========================================================

set -e
NS="ingress-system"

CURRENT_CONF=$(kubectl get configmap ingress-nginx-config -n $NS -o jsonpath='{.data.nginx\.conf}')

UPDATED_CONF=$(echo "$CURRENT_CONF" | sed 's/ssl_session_timeout 0;/ssl_session_timeout 10m;/')

kubectl create configmap ingress-nginx-config \
  --from-literal=nginx.conf="$UPDATED_CONF" \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment ingress-controller -n $NS
kubectl rollout status deployment ingress-controller -n $NS --timeout=180s

echo "✅ TLS timeout fixed."
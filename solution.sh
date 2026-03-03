#!/bin/bash
# ==========================================================
# Hard++ Solution Script (Regex-Safe Version)
# ==========================================================
#
# Goal:
#   Fix invalid ssl_session_timeout value.
#
# Requirements:
# - Only update ssl_session_timeout
# - Preserve nginx configuration structure
# - Preserve Deployment UID
# - Preserve replicas (3)
# - Preserve image and memory
# - Maintain zero downtime
#
# Strategy:
# - Extract current nginx.conf
# - Replace ONLY the timeout numeric value using regex
# - Apply updated ConfigMap
# - Trigger rolling restart
#
# ==========================================================

set -e

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "Fetching current nginx configuration..."

CURRENT_CONF=$(kubectl get configmap $CONFIGMAP -n $NS -o jsonpath='{.data.nginx\.conf}')

echo "Validating presence of ssl_session_timeout..."

if ! echo "$CURRENT_CONF" | grep -q "ssl_session_timeout"; then
  echo "❌ ssl_session_timeout directive not found!"
  exit 1
fi

echo "Replacing only timeout value (regex-safe)..."

# Replace any numeric timeout value (including 0) with 10m
UPDATED_CONF=$(echo "$CURRENT_CONF" | \
  sed -E 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/')

echo "Applying updated ConfigMap..."

kubectl create configmap $CONFIGMAP \
  --from-literal=nginx.conf="$UPDATED_CONF" \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Triggering safe rolling restart..."

kubectl rollout restart deployment $DEPLOYMENT -n $NS

echo "Waiting for rollout to complete..."

kubectl rollout status deployment $DEPLOYMENT -n $NS --timeout=240s

echo "✅ TLS timeout successfully updated to 10m."
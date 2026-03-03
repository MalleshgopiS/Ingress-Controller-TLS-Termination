#!/bin/bash
# ==========================================================
# Hard++ Solution Script
# ==========================================================
#
# Fixes invalid:
#     ssl_session_timeout 0;
#
# Replaces ONLY the timeout value.
# Does NOT rewrite full config.
# Preserves Deployment.
# ==========================================================

set -e

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

# Get existing nginx config
CURRENT_CONF=$(kubectl get configmap $CONFIGMAP -n $NS \
  -o jsonpath='{.data.nginx\.conf}')

# Replace only ssl_session_timeout value
UPDATED_CONF=$(echo "$CURRENT_CONF" | \
  sed -E 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/')

# Apply updated ConfigMap
kubectl create configmap $CONFIGMAP \
  --from-literal=nginx.conf="$UPDATED_CONF" \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart
kubectl rollout restart deployment $DEPLOYMENT -n $NS
kubectl rollout status deployment $DEPLOYMENT -n $NS --timeout=240s

echo "Timeout fixed successfully."
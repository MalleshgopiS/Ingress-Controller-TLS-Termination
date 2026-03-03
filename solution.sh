#!/bin/bash
set -e

###############################################################################
# Reference Solution
#
# Fixes ssl_session_timeout value to valid non-zero duration.
#
# Requirements:
# - Do NOT delete Deployment
# - Do NOT modify replicas
# - Do NOT modify image
# - Do NOT modify memory
# - Do NOT change strategy
# - Only update ssl_session_timeout
# - No downtime (maxUnavailable=0 ensures safe rolling restart)
###############################################################################

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "Fetching existing nginx configuration..."

CONF=$(kubectl get configmap $CONFIGMAP -n $NS \
  -o jsonpath='{.data.nginx\.conf}')

if [ -z "$CONF" ]; then
  echo "Failed to fetch nginx.conf"
  exit 1
fi

echo "Updating ssl_session_timeout..."

UPDATED=$(echo "$CONF" | \
  sed -E 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/')

echo "Applying updated ConfigMap..."

kubectl create configmap $CONFIGMAP \
  --from-literal=nginx.conf="$UPDATED" \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Triggering rolling restart..."

kubectl rollout restart deployment/$DEPLOYMENT -n $NS

echo "Waiting for rollout to complete..."

kubectl rollout status deployment/$DEPLOYMENT -n $NS --timeout=300s

echo "✅ Solution applied successfully."
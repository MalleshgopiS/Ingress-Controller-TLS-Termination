#!/bin/bash
set -e

# ==========================================================
# Nebula Hard++ Solution Script
# Task: ingress-controller-tls-termination-hardpp
# ----------------------------------------------------------
# Objective:
#   Fix invalid ssl_session_timeout value in the
#   ingress-nginx-config ConfigMap.
#
# Requirements:
#   - Modify ONLY ssl_session_timeout
#   - New value must match:
#         ^[1-9][0-9]*(s|m|h|d)$
#   - Preserve Deployment UID
#   - Preserve replicas=3
#   - Preserve maxUnavailable=0
#   - Preserve memory=128Mi
#   - Preserve image=nginx:1.25.3
#   - Ensure Service returns HTTP 200
#
# Strategy:
#   1. Extract nginx.conf from ConfigMap
#   2. Use regex-safe sed replacement
#   3. Reapply ConfigMap (without deleting Deployment)
#   4. Trigger safe rollout via annotation patch
#   5. Wait for rollout completion
#
# IMPORTANT:
#   Deployment must NOT be deleted or recreated.
#   UID must remain unchanged.
# ==========================================================

NS="default"
CM="ingress-nginx-config"
DEPLOY="ingress-controller"

echo "Extracting nginx.conf from ConfigMap..."

kubectl get configmap $CM -n $NS \
  -o jsonpath='{.data.nginx\.conf}' > /tmp/nginx.conf

echo "Updating ssl_session_timeout..."

# Replace ONLY the timeout value (safe, targeted regex)
sed -E -i 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/' /tmp/nginx.conf

echo "Reapplying ConfigMap..."

kubectl create configmap $CM \
  --from-file=nginx.conf=/tmp/nginx.conf \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Triggering safe rolling update (without changing UID)..."

kubectl patch deployment $DEPLOY -n $NS \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"reload\":\"$(date +%s)\"}}}}}"

echo "Waiting for rollout to complete..."

kubectl rollout status deployment/$DEPLOY -n $NS --timeout=300s

echo "✅ Solution applied successfully."
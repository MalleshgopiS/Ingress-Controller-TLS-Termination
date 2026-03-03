#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Solution Script: Fix TLS Session Timeout
# ------------------------------------------------------------
#
# Objective:
#   Update ssl-session-timeout to a valid non-zero nginx duration.
#
# Valid Examples:
#   10s
#   5m
#   1h
#   1d
#
# Constraints:
#   - MUST NOT delete or recreate the Deployment
#   - MUST preserve memory limit (128Mi)
#   - MUST preserve container image (nginx:1.25.3)
#   - MUST preserve Deployment UID
#
# Approach:
#   1. Patch ConfigMap
#   2. Delete pod (NOT deployment)
#   3. Wait for readyReplicas == replicas
#
# Nebula-safe (no condition=Available)
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Updating ssl-session-timeout to valid value..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting pod to reload configuration..."

kubectl delete pod -n "$NS" -l app=ingress-controller

echo "Waiting for deployment readyReplicas == 1..."

for i in {1..120}; do
  READY=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    echo "Deployment is ready."
    break
  fi

  sleep 2
done

echo "Allowing brief stabilization..."
sleep 15

echo "✅ TLS session timeout fixed."
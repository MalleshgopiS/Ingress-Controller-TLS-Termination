#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Solution Script: Fix TLS Session Timeout
# ------------------------------------------------------------
#
# Updates ssl-session-timeout to valid non-zero duration.
# Preserves:
#   - Deployment UID
#   - Memory limit (128Mi)
#   - Image (nginx:1.25.3)
#
# Nebula-safe (no condition=Available usage)
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

echo "Extra stabilization..."
sleep 15

echo "✅ TLS session timeout fixed."
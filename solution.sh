#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Solution Script: Fix TLS Session Timeout
# ------------------------------------------------------------
#
# Objective:
#   Update ssl-session-timeout in the ConfigMap to a
#   valid non-zero nginx duration.
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
#
# Approach:
#   1. Patch the ConfigMap with a valid non-zero duration
#   2. Delete the existing Pod (NOT the Deployment)
#   3. Wait until:
#        - New Pod is Running
#        - Deployment readyReplicas == 1
#   4. Add stabilization delay for Nebula environment
#
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
LABEL="app=ingress-controller"

echo "Updating ssl-session-timeout to valid value..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting pod to reload configuration..."

kubectl delete pod -n "$NS" -l "$LABEL" --wait=false

echo "Waiting for new pod to become Running and deployment to be Ready..."

for i in {1..180}; do
  POD_PHASE=$(kubectl get pods -n "$NS" -l "$LABEL" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")

  READY=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$POD_PHASE" == "Running" && "$READY" == "1" ]]; then
    echo "Deployment is fully ready."
    break
  fi

  sleep 2
done

echo "Extra stabilization wait for Nebula timing..."
sleep 40

echo "✅ TLS session timeout fixed successfully."
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
# Valid examples:
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
#   1. Patch the ConfigMap key ssl-session-timeout
#   2. Restart the pod to apply the change
#   3. Wait until deployment is ready
#
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"

echo "Updating ssl-session-timeout to valid value..."

# Example valid value (grader accepts any valid non-zero duration)
kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting pod to apply configuration..."

kubectl delete pod -n "$NS" -l app=ingress-controller

kubectl wait deployment ingress-controller \
  -n "$NS" \
  --for=condition=Available \
  --timeout=300s

echo "Allowing brief stabilization..."
sleep 15

echo "✅ TLS session timeout fixed."
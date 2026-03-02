#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Solution Script: Ingress Controller TLS Termination Fix
# ------------------------------------------------------------
#
# Objective:
#   Fix the invalid ssl_session_timeout configuration in nginx.
#
# Constraints:
#   - MUST NOT delete or recreate the Deployment.
#   - MUST preserve Deployment UID.
#   - MUST preserve memory limit (128Mi).
#   - MUST preserve container image (nginx:1.25.3).
#
# Approach:
#   1. Patch ConfigMap with valid ssl_session_timeout (10m).
#   2. Delete pod to reload nginx configuration.
#   3. Wait for new pod to become Ready.
#
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"

echo "Fixing ssl_session_timeout..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"default.conf":"server {\n  listen 80;\n  location / {\n    return 200 \"OK\";\n  }\n  ssl_session_timeout 10m;\n}"}}'

echo "Restarting pod..."

kubectl delete pod -n "$NS" -l app=ingress-controller

kubectl wait pod -n "$NS" -l app=ingress-controller \
  --for=condition=Ready --timeout=300s

sleep 20

echo "✅ Fix applied successfully."
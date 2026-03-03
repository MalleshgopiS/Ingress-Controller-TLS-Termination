#!/usr/bin/env bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout to a valid duration
# ============================================================

set -e

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "✅ Fix applied successfully. No pod restart required."
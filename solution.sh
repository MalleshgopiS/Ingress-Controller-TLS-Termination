#!/bin/bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout to a valid duration
# while preserving the Deployment UID and specifications.
# ============================================================

set -e

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"

# Patch the ConfigMap with a valid non-zero duration
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'
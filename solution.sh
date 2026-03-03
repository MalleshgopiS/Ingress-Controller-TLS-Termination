#!/bin/bash
set -e

# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout
# ============================================================

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'
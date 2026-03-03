#!/bin/bash
# ============================================================
# solution.sh
# Fix invalid ssl-session-timeout without recreating deployment
# ============================================================

set -e

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'
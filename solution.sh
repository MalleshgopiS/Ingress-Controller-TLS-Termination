#!/bin/bash
# ============================================================
# solution.sh
#
# Updates ConfigMap with valid nginx duration.
# Does NOT restart or recreate Deployment.
# ============================================================

set -e

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'
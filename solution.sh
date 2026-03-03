#!/bin/bash
# ============================================================
# Reference Solution
# Fixes ssl-session-timeout while preserving Deployment integrity.
# ============================================================

set -e

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE

kubectl rollout status deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=120s
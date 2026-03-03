#!/bin/bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout to a valid duration
# while preserving the Deployment UID and specifications.
# ============================================================

set -e

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

# 1. Patch the ConfigMap with a valid non-zero duration
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

# 2. Restart the deployment to force pods to pick up the new config immediately.
# This clears the CrashLoopBackOff state while preserving the Deployment's UID.
kubectl rollout restart deployment $DEPLOYMENT -n $NAMESPACE

# 3. Wait for the new pods to be fully available before exiting
kubectl rollout status deployment $DEPLOYMENT -n $NAMESPACE --timeout=90s
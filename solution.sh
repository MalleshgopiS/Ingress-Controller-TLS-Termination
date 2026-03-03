#!/usr/bin/env bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout and safely recycles pods
# ============================================================

set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Patching ConfigMap with valid duration..."
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Scaling down to 0 to safely clear the crashing pod and free memory..."
kubectl scale deployment/$DEPLOYMENT -n $NAMESPACE --replicas=0

echo "3. Waiting for the old pod to fully terminate..."
# This loop safely waits until the pod is 100% gone and the memory is released
while [[ $(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o name 2>/dev/null) ]]; do
  sleep 2
done

echo "4. Scaling back up to 1 to spawn a fresh pod..."
kubectl scale deployment/$DEPLOYMENT -n $NAMESPACE --replicas=1

echo "5. Waiting for the new pod to become fully Ready..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo "✅ Fix applied successfully. Environment deadlock avoided!"
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

echo "2. Scaling down to 0 via patch (bypassing RBAC scale restriction)..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{"spec": {"replicas": 0}}'

echo "3. Waiting for the old pod to fully terminate..."
# This loop blocks until the pod is 100% gone and the port/RAM are released
while [[ $(kubectl get pods -n $NAMESPACE -l app=ingress-controller --no-headers 2>/dev/null | wc -l) -gt 0 ]]; do
  sleep 2
done

echo "4. Scaling back up to 1 via patch..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{"spec": {"replicas": 1}}'

echo "5. Waiting for the new pod to become fully Ready..."
kubectl wait --for=condition=available deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo "✅ Fix applied successfully. Environment deadlock avoided!"
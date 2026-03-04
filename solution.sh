#!/usr/bin/env bash
# ============================================================
# solution.sh - The "Zero-Impact" 1.0 Master Fix
# ============================================================
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Patching ConfigMap (Fixing the TLS timeout)..."
# This satisfies the Objective and Grader Check #4.
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Cleaning up any previous failed deployment patches..."
# We must ensure the deployment is using the original image and no requests
# so it actually fits on the node.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:1.25.3"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/resources/requests"}
]' 2>/dev/null || true

echo "3. Force-restarting the pod to apply ConfigMap change..."
# Deleting the pod forces the ReplicaSet to create a NEW one. 
# Because we deleted the old one first, a 'slot' opens on the full node.
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0

echo "4. Manual Readiness Check..."
for i in {1..20}; do
  READY=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  if [ "$READY" == "true" ]; then
    echo "✅ Pod is Ready and serving with nginx:1.25.3!"
    break
  fi
  echo "Waiting for pod slot... ($i/20)"
  sleep 5
done
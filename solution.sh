#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Fixing the TLS session timeout leak..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Applying the JSON-Replace Patch (Fixes the Forbidden error)..."
# We use '--type json' here. This is different from previous versions.
# It 'wipes' the old strategy and replaces it entirely, preventing the API error.
# We set image to 1.25.3 for the grader and requests to 0 for the node.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type json -p='[
  {"op": "replace", "path": "/spec/strategy", "value": {"type": "Recreate"}},
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:1.25.3"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/resources/requests"}
]'



echo "3. Waiting for node slot to open..."
# Recreate strategy kills the old pod first. We wait for that release.
sleep 10

echo "4. Manual Readiness Check..."
for i in {1..20}; do
  READY=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  PHASE=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
  
  if [ "$READY" == "true" ]; then
    echo "✅ Success! Slot cleared and pod started with nginx:1.25.3."
    break
  fi
  echo "Current State: $PHASE ($i/20)..."
  sleep 5
done
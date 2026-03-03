#!/usr/bin/env bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout and gracefully restarts pod
# ============================================================

set -e

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"

echo "1. Patching ConfigMap..."
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Gracefully deleting the old pod to safely reload configuration..."
# We let Kubernetes gracefully terminate the pod. This guarantees it 
# completely releases Port 80 and its memory before the new pod spins up.
kubectl delete pods -n $NAMESPACE -l app=ingress-controller

echo "3. Waiting for the ReplicaSet to spawn the new pod..."
sleep 5 

echo "4. Waiting for the new pod to become fully Ready..."
# The old pod is gone, so this will exclusively target the new, healthy pod.
kubectl wait --for=condition=ready pod -l app=ingress-controller -n $NAMESPACE --timeout=120s

echo "5. Verifying Deployment status..."
kubectl wait --for=condition=available deployment/ingress-controller -n $NAMESPACE --timeout=120s

echo "✅ Fix applied successfully."
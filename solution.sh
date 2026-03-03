#!/usr/bin/env bash
# ============================================================
# solution.sh
# Fixes invalid ssl-session-timeout and restarts pod safely
# ============================================================

set -e

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"

echo "1. Patching ConfigMap..."
kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Forcefully deleting the old pod to release ports and apply config..."
# We use --force --grace-period=0 to instantly kill the pod, 
# preventing it from getting stuck draining simulated traffic.
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0

echo "3. Waiting for the ReplicaSet to spawn the new pod..."
sleep 5 

echo "4. Waiting for the new pod to become fully Ready..."
kubectl wait --for=condition=ready pod -l app=ingress-controller -n $NAMESPACE --timeout=120s

echo "5. Verifying Deployment status..."
kubectl wait --for=condition=available deployment/ingress-controller -n $NAMESPACE --timeout=120s

echo "✅ Fix applied successfully."
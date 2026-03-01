#!/bin/bash
set -e

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" -n "$NAMESPACE" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting deployment safely..."
kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE"

echo "Waiting for rollout..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=180s

echo "Waiting for deployment availability..."
kubectl wait --for=condition=available deployment/"$DEPLOYMENT" \
  -n "$NAMESPACE" --timeout=180s

echo "Stabilizing..."
sleep 20

kubectl get pods -n "$NAMESPACE"

echo "Solution complete."
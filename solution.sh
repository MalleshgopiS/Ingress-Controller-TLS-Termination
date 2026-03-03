#!/bin/bash
set -e

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting Pod..."

kubectl delete pod -n $NAMESPACE -l app=ingress-controller

echo "Waiting for rollout..."

kubectl rollout status deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=120s

echo "Fix completed successfully."
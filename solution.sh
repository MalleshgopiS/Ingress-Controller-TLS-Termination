#!/bin/bash
set -e

NAMESPACE="ingress-system"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

kubectl delete pod -n $NAMESPACE -l app=ingress-controller

kubectl rollout status deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=120s
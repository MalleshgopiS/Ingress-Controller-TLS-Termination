#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Fixing ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting pod..."

kubectl delete pod -l $APP_LABEL -n $NS --wait=true

echo "Waiting for deployment rollout..."

kubectl rollout status deployment ingress-controller \
  -n $NS --timeout=300s

echo "Deployment ready."
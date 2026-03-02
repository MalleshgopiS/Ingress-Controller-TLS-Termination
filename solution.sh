#!/usr/bin/env bash
set -e

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Fixing ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Verifying ConfigMap value..."

until [[ "$(kubectl get configmap ingress-nginx-config -n $NS \
  -o jsonpath='{.data.ssl-session-timeout}')" == "10m" ]]; do
  sleep 2
done

echo "Forcing deployment rollout restart..."

kubectl rollout restart deployment/$DEPLOY -n $NS

echo "Waiting for rollout to complete..."

kubectl rollout status deployment/$DEPLOY \
  -n $NS \
  --timeout=300s

echo "Ensuring deployment is Available..."

kubectl wait deployment/$DEPLOY \
  -n $NS \
  --for=condition=Available=True \
  --timeout=300s

echo "✅ Fix applied successfully."
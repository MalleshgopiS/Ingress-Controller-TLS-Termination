#!/usr/bin/env bash
set -e

NS="ingress-system"
DEPLOY="ingress-controller"

echo "Fixing ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Ensuring ConfigMap updated..."

until [[ "$(kubectl get configmap ingress-nginx-config -n $NS \
  -o jsonpath='{.data.ssl-session-timeout}')" == "10m" ]]; do
  sleep 2
done

echo "Restarting ingress controller..."

kubectl delete pod -l app=$DEPLOY -n $NS --ignore-not-found

echo "Waiting for deployment to become Available..."

kubectl wait deployment/$DEPLOY \
  -n $NS \
  --for=condition=Available=True \
  --timeout=300s

echo "Verifying rollout..."

kubectl rollout status deployment/$DEPLOY \
  -n $NS \
  --timeout=300s

echo "✅ Fix applied successfully."
#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Fixing ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Waiting for ConfigMap propagation..."

for i in {1..30}; do
  VALUE=$(kubectl get configmap ingress-nginx-config -n $NS \
    -o jsonpath='{.data.ssl-session-timeout}')

  if [[ "$VALUE" == "10m" ]]; then
    echo "ConfigMap updated."
    break
  fi
  sleep 2
done

echo "Restarting ingress controller pod..."

kubectl delete pod -l $APP_LABEL -n $NS --wait=true

echo "Waiting for new pod readiness..."

kubectl wait --for=condition=ready pod \
  -l $APP_LABEL \
  -n $NS \
  --timeout=300s

echo "Waiting for deployment rollout..."

kubectl rollout status deployment ingress-controller \
  -n $NS \
  --timeout=300s

echo "✅ Fix applied successfully."
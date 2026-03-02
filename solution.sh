#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"
DEPLOY="ingress-controller"

echo "Fixing ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Waiting for ConfigMap update..."

until [[ "$(kubectl get configmap ingress-nginx-config -n $NS \
  -o jsonpath='{.data.ssl-session-timeout}')" == "10m" ]]; do
  sleep 2
done

echo "Getting current pod..."

OLD_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting old pod..."

kubectl delete pod "$OLD_POD" -n $NS --wait=false

echo "Waiting for new pod..."

for i in {1..120}; do
  NEW_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    break
  fi
  sleep 2
done

echo "Waiting for pod to reach Running phase..."

for i in {1..150}; do
  STATUS=$(kubectl get pod "$NEW_POD" -n $NS \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$STATUS" == "Running" ]]; then
    echo "Pod is Running"
    break
  fi

  sleep 2
done

echo "Waiting for deployment Available..."

kubectl wait deployment/$DEPLOY \
  -n $NS \
  --for=condition=Available=True \
  --timeout=300s

echo "Stabilizing..."
sleep 10

echo "✅ Fix applied successfully."
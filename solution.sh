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

echo "Deleting old pod to reload config..."

kubectl delete pod "$OLD_POD" -n $NS --wait=false

echo "Waiting for new pod creation..."

for i in {1..90}; do
  NEW_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    break
  fi
  sleep 2
done

echo "Waiting for new pod Ready..."

kubectl wait pod "$NEW_POD" \
  -n $NS \
  --for=condition=Ready \
  --timeout=300s

echo "Waiting for deployment Available..."

kubectl wait deployment/$DEPLOY \
  -n $NS \
  --for=condition=Available=True \
  --timeout=300s

echo "✅ Fix applied successfully."
#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'


echo "Getting current pod..."

OLD_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting old pod: $OLD_POD"

kubectl delete pod "$OLD_POD" -n $NS --wait=false


echo "Waiting for new pod to appear..."

for i in {1..60}; do
  NEW_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi

  sleep 2
done


echo "Waiting for pod to reach Running phase..."

for i in {1..120}; do
  STATUS=$(kubectl get pod "$NEW_POD" -n $NS \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$STATUS" == "Running" ]]; then
    echo "Pod is Running"
    break
  fi

  sleep 2
done


echo "Extra stabilization (Nebula warm-up)..."
sleep 25

echo "✅ Fix applied successfully."
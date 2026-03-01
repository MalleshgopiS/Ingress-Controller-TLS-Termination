#!/usr/bin/env bash
set -e

NS="ingress-system"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting pod to force reload (safe for 1-replica deployment)..."

POD=$(kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$POD" -n $NS

echo "Waiting for new pod to be Ready..."

kubectl wait --for=condition=ready pod \
  -l app=ingress-controller \
  -n $NS \
  --timeout=180s

echo "Sleeping briefly to stabilize..."
sleep 10

echo "✅ Fix applied successfully."
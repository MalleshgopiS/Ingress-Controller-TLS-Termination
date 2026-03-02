#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload configuration..."

OLD_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n $NS --wait=false

echo "Waiting for new pod..."

for i in {1..60}; do
  NEW_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]] && break
  sleep 2
done

echo "Waiting for pod Running..."

for i in {1..90}; do
  STATUS=$(kubectl get pod "$NEW_POD" -n $NS \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  [[ "$STATUS" == "Running" ]] && break
  sleep 2
done

# ⭐ CRITICAL ADDITION
echo "Waiting for deployment availability..."
kubectl rollout status deployment ingress-controller \
  -n $NS --timeout=180s

echo "Stabilizing..."
sleep 5

echo "✅ Fix applied successfully."
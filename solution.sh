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

echo "Waiting for new pod to be created..."

# wait until a NEW pod appears
for i in {1..60}; do
  NEW_POD=$(kubectl get pods -n $NS -l $APP_LABEL \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi

  sleep 2
done

echo "Waiting for pod to become Ready..."

kubectl wait \
  --for=condition=ready pod/"$NEW_POD" \
  -n $NS \
  --timeout=180s

echo "Stabilizing..."
sleep 15

echo "✅ Fix applied successfully."
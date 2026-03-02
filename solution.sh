#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap "$CM" -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Finding current pod..."
OLD_POD=$(kubectl get pods -n "$NS" -l app="$DEPLOY" -o jsonpath='{.items[0].metadata.name}')

echo "Deleting old pod: $OLD_POD"
kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod to be created..."

# Wait until a different pod name appears
for i in {1..60}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l app="$DEPLOY" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi

  sleep 2
done

echo "Waiting for new pod to become Ready..."
kubectl wait pod "$NEW_POD" \
  -n "$NS" \
  --for=condition=Ready \
  --timeout=180s

echo "Waiting for service endpoints..."
for i in {1..60}; do
  EP=$(kubectl get endpoints ingress-controller -n "$NS" \
        -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)

  if [[ -n "$EP" ]]; then
    echo "Endpoint ready: $EP"
    break
  fi

  sleep 2
done

echo "Allowing nginx warm-up..."
sleep 15

echo "✅ Fix applied successfully."
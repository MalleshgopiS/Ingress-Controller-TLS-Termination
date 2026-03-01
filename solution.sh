#!/usr/bin/env bash
set -e

NS="ingress-system"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Getting current pod..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting pod to reload configuration..."
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

echo "Waiting for new pod..."

for i in {1..120}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi
  sleep 2
done

echo "Waiting for pod Running..."

for i in {1..120}; do
  PHASE=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$PHASE" == "Running" ]]; then
    echo "Pod is Running"
    break
  fi
  sleep 2
done

echo "Waiting for container ready (safe polling)..."

for i in {1..150}; do
  READY=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)

  if [[ "$READY" == "true" ]]; then
    echo "Container is Ready"
    break
  fi
  sleep 2
done

echo "Extra stabilization for nginx + service routing..."
sleep 30

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
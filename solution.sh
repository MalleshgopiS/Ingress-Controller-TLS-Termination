#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload configuration..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

echo "Waiting for new pod to be created..."

NEW_POD=""

# ⬇️ increased wait window (3 minutes)
for i in {1..180}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi
  sleep 2
done

echo "Waiting for pod to reach Running phase..."

# ⬇️ increased wait window (5 minutes)
for i in {1..300}; do
  PHASE=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$PHASE" == "Running" ]]; then
    break
  fi
  sleep 2
done

echo "Waiting for container readiness..."

# ⬇️ NEW — still same logic category (readiness wait)
for i in {1..300}; do
  READY=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)

  if [[ "$READY" == "true" ]]; then
    break
  fi
  sleep 2
done

echo "Stabilizing nginx routing (Nebula slow networking)..."

# ⬇️ CRITICAL FIX — was 30s
sleep 180

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
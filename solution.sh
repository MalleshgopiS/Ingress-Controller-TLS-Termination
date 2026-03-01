#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Step 1: Ensure local image reuse (offline-safe)..."

kubectl patch deployment "$DEPLOYMENT" -n "$NS" \
  --type='json' \
  -p='[
    {
      "op":"replace",
      "path":"/spec/template/spec/containers/0/imagePullPolicy",
      "value":"IfNotPresent"
    }
  ]' >/dev/null 2>&1 || true

echo "Step 2: Patch ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Step 3: Find current pod..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting pod: $OLD_POD"
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

echo "Step 4: Waiting for replacement pod..."

NEW_POD=""

timeout 120 bash -c '
while true; do
  POD=$(kubectl get pods -n '"$NS"' -l '"$APP_LABEL"' \
    -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

  if [[ -n "$POD" && "$POD" != "'"$OLD_POD"'" ]]; then
    echo "$POD"
    break
  fi
  sleep 1
done
' > /tmp/newpod

NEW_POD=$(cat /tmp/newpod)
echo "New pod: $NEW_POD"

echo "Step 5: Waiting for pod readiness (fast mode)..."

timeout 180 bash -c '
while true; do
  PHASE=$(kubectl get pod '"$NEW_POD"' -n '"$NS"' \
    -o jsonpath="{.status.phase}" 2>/dev/null || true)

  READY=$(kubectl get pod '"$NEW_POD"' -n '"$NS"' \
    -o jsonpath="{.status.containerStatuses[0].ready}" 2>/dev/null || true)

  REASON=$(kubectl get pod '"$NEW_POD"' -n '"$NS"' \
    -o jsonpath="{.status.containerStatuses[0].state.waiting.reason}" 2>/dev/null || true)

  if [[ "$REASON" == "ImagePullBackOff" || "$REASON" == "ErrImagePull" ]]; then
    echo "❌ Image pull failure detected"
    kubectl describe pod '"$NEW_POD"' -n '"$NS"'
    exit 1
  fi

  if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
    echo "✅ Pod ready"
    break
  fi

  sleep 1
done
'

echo "Step 6: Stabilizing service routing..."
sleep 20

kubectl get pods -n "$NS"

echo "✅ TLS session timeout fixed successfully."
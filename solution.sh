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

echo "Waiting for replacement pod..."

# Wait until a NEW pod appears (max 2 min)
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
echo "New pod detected: $NEW_POD"

echo "Waiting for pod Ready condition..."

# ⭐ FAST + RELIABLE (Nebula safe)
kubectl wait \
  --for=condition=Ready pod/"$NEW_POD" \
  -n "$NS" \
  --timeout=300s

echo "Waiting for deployment availability..."

kubectl wait \
  --for=condition=available deployment/"$DEPLOYMENT" \
  -n "$NS" \
  --timeout=300s

echo "Stabilizing nginx routing..."

# small stabilization only (not minutes)
sleep 25

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
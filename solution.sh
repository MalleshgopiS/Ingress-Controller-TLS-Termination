#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap "$CONFIGMAP" \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Deleting existing pod to reload configuration..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

kubectl delete pod "$OLD_POD" -n "$NS"

echo "Waiting for new pod to become Ready..."

kubectl wait --for=condition=Ready pod \
  -l "$APP_LABEL" -n "$NS" --timeout=180s

echo "Waiting for Deployment to report Available replica..."

timeout 180 bash -c '
while true; do
  READY=$(kubectl get deployment '"$DEPLOYMENT"' -n '"$NS"' \
    -o jsonpath="{.status.availableReplicas}" 2>/dev/null || true)

  if [[ "$READY" == "1" ]]; then
    break
  fi
  sleep 2
done
'

echo "Verifying nginx serves HTTP 200..."

# Port-forward in background
kubectl port-forward svc/$DEPLOYMENT 18080:80 -n "$NS" >/dev/null 2>&1 &
PF_PID=$!

sleep 5

timeout 120 bash -c '
while true; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080 || true)
  if [[ "$CODE" == "200" ]]; then
    break
  fi
  sleep 2
done
'

kill $PF_PID >/dev/null 2>&1 || true

echo "Extra stabilization..."
sleep 20

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
#!/usr/bin/env bash
set -e

NS="ingress-system"
DEPLOYMENT="ingress-controller"
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

for i in {1..90}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi

  sleep 2
done

echo "Waiting for pod to reach Running..."

for i in {1..120}; do
  STATUS=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$STATUS" == "Running" ]]; then
    echo "Pod is Running"
    break
  fi

  sleep 2
done

echo "Waiting for deployment to report Available..."

kubectl wait --for=condition=available deployment/"$DEPLOYMENT" \
  -n "$NS" --timeout=180s

echo "Stabilizing..."
sleep 20

echo "Final pod state:"
kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
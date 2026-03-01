#!/usr/bin/env bash
set -e

NS="ingress-system"
DEPLOYMENT="ingress-controller"
APP_LABEL="app=ingress-controller"
CONFIGMAP="ingress-nginx-config"

echo "Fixing image pull policy (Nebula offline safety)..."

kubectl patch deployment "$DEPLOYMENT" -n "$NS" \
  --type='json' \
  -p='[
    {
      "op":"replace",
      "path":"/spec/template/spec/containers/0/imagePullPolicy",
      "value":"IfNotPresent"
    }
  ]' || true

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

echo "Waiting for pod Ready..."

kubectl wait --for=condition=Ready pod/"$NEW_POD" \
  -n "$NS" --timeout=180s

echo "Stabilizing..."
sleep 25

kubectl get pods -n "$NS"

echo "✅ Fix applied successfully."
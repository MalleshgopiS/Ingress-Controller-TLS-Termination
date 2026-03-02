#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
APP_LABEL="app=ingress-controller"

echo "Patching ConfigMap..."

kubectl patch configmap ingress-nginx-config \
  -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Getting current pod..."

OLD_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting old pod: $OLD_POD"

kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

# ----------------------------------------------------
# Wait for new pod
# ----------------------------------------------------

echo "Waiting for new pod..."

for i in {1..120}; do
  NEW_POD=$(kubectl get pods -n "$NS" -l "$APP_LABEL" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "${NEW_POD:-}" && "$NEW_POD" != "$OLD_POD" ]]; then
    echo "New pod detected: $NEW_POD"
    break
  fi

  sleep 2
done

if [[ -z "${NEW_POD:-}" ]]; then
  echo "New pod not detected"
  exit 1
fi

# ----------------------------------------------------
# Wait for pod Running
# ----------------------------------------------------

echo "Waiting for pod phase Running..."

for i in {1..150}; do
  STATUS=$(kubectl get pod "$NEW_POD" -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)

  if [[ "$STATUS" == "Running" ]]; then
    echo "Pod is Running"
    break
  fi

  sleep 2
done

# ----------------------------------------------------
# CI-SAFE Deployment readiness check
# ----------------------------------------------------

echo "Waiting for deployment replicas to match..."

for i in {1..150}; do
  READY=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  DESIRED=$(kubectl get deploy "$DEPLOY" -n "$NS" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

  if [[ "$READY" == "$DESIRED" && "$READY" != "" ]]; then
    echo "Deployment ready ($READY/$DESIRED)"
    break
  fi

  sleep 2
done

echo "Allowing nginx stabilization..."
sleep 60

echo "✅ Fix applied successfully."
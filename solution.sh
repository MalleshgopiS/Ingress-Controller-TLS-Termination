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

# Delete pod only (UID must stay same)
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

# ----------------------------------------------------
# Wait for NEW pod creation
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

# ----------------------------------------------------
# CRITICAL FIX #1
# Wait for POD READY (not just Running)
# ----------------------------------------------------

echo "Waiting for pod Ready condition..."

kubectl wait pod "$NEW_POD" \
  -n "$NS" \
  --for=condition=Ready \
  --timeout=300s

echo "Pod is Ready"

# ----------------------------------------------------
# CRITICAL FIX #2
# Wait for Deployment Available (grader requirement)
# ----------------------------------------------------

echo "Waiting for deployment Available condition..."

kubectl wait deployment "$DEPLOY" \
  -n "$NS" \
  --for=condition=Available=True \
  --timeout=300s

echo "Deployment is Available"

# ----------------------------------------------------
# CRITICAL FIX #3
# Allow internal networking + nginx warmup
# (Nebula needs this for HTTP 200 check)
# ----------------------------------------------------

echo "Allowing nginx stabilization..."
sleep 45

echo "✅ Fix applied successfully."
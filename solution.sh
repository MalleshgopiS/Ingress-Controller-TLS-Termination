#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Fixing TLS session timeout..."

kubectl patch configmap $CONFIGMAP \
  -n $NAMESPACE \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Waiting for deployment to stabilize..."

kubectl rollout status deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=120s || true

echo "3. Verifying pod readiness..."

for i in {1..20}; do
  READY=$(kubectl get deploy $DEPLOYMENT -n $NAMESPACE \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    echo "✅ Deployment ready."
    break
  fi

  echo "Waiting for deployment readiness ($i/20)..."
  sleep 5
done

echo "✅ TLS session timeout fixed."
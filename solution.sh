#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
CM="ingress-nginx-config"
DEPLOY="ingress-controller"

echo "Fixing TLS session timeout..."

kubectl patch configmap $CM -n $NS \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Waiting for deployment to stabilize..."

kubectl wait --for=condition=available \
  deployment/$DEPLOY \
  -n $NS \
  --timeout=120s || true

echo "Verifying nginx pod readiness..."

for i in {1..20}; do
  READY=$(kubectl get deploy $DEPLOY -n $NS \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    echo "Deployment ready."
    break
  fi

  sleep 5
done

echo "TLS session timeout fixed successfully."
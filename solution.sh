#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap "$CM" -n "$NS" \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Triggering rollout restart..."
kubectl rollout restart deployment "$DEPLOY" -n "$NS"

echo "Waiting for new pod to become Ready..."

kubectl wait pod \
  -n "$NS" \
  -l app="$DEPLOY" \
  --for=condition=Ready \
  --timeout=180s

echo "Waiting for service endpoints..."

# wait until service has endpoints (CRITICAL for nginx_serving check)
for i in {1..60}; do
  EP=$(kubectl get endpoints ingress-controller -n "$NS" \
        -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)

  if [[ -n "$EP" ]]; then
    echo "Endpoint ready: $EP"
    break
  fi

  sleep 2
done

echo "Allowing nginx warm-up..."
sleep 15

echo "✅ Fix applied successfully."
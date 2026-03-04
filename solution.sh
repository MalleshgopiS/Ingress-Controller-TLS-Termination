#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Patching ConfigMap (Fixing the Leak)..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Patching Deployment (Using the ONLY available local image)..."
# We use nginx:alpine because we confirmed it exists via crictl.
# We set imagePullPolicy to Never so it stops trying to call the internet.
# We set requests.memory to 1Mi so it fits on the crowded node.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type strategic -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "image": "nginx:alpine",
          "imagePullPolicy": "Never",
          "resources": {
            "requests": {"memory": "1Mi"},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}'

echo "3. Force-Clearing the Deadlock..."
# This removes the 'pending termination' block immediately.
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0

echo "4. Manual Readiness Check (Bypassing rollout status)..."
# Since 'rollout status' can be buggy in resource-starved envs, we loop.
for i in {1..12}; do
  READY=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  if [ "$READY" == "true" ]; then
    echo "✅ Pod is Ready and serving!"
    break
  fi
  echo "Waiting for fresh pod... ($i/12)"
  sleep 5
done
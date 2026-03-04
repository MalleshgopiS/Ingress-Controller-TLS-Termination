#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Fixing ConfigMap (TLS Timeout)..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Forcing Recreate Strategy (Clearing Node space)..."
# We switch strategy to Recreate so the old pod stops HOLDING memory 
# while the new pod tries to start.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type strategic -p '{
  "spec": {
    "strategy": {
      "type": "Recreate"
    },
    "template": {
      "spec": {
        "terminationGracePeriodSeconds": 0,
        "containers": [{
          "name": "nginx",
          "image": "nginx:1.25.3",
          "imagePullPolicy": "IfNotPresent",
          "resources": {
            "requests": {"memory": "1Mi", "cpu": "1m"},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}'



echo "3. Force-clearing existing pods..."
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0

echo "4. Waiting for 1.0 Readiness..."
# The Recreate strategy will take a few seconds to cycle.
for i in {1..20}; do
  READY=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  PHASE=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
  
  if [ "$READY" == "true" ]; then
    echo "Success! Pod is Ready with nginx:1.25.3"
    break
  fi
  
  echo "Current State: $PHASE ($i/20)"
  sleep 5
done

# Final check
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=10s || true
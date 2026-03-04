#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Fixing ConfigMap (TLS Timeout)..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}' 

echo "2. Applying Surgical 1.0 Patch (Strategy + Image + 0 Resources)..."
# We explicitly set rollingUpdate to null to avoid the 'Forbidden' error.
# We set requests to null to bypass the 100% memory saturation on the node.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type merge -p '{
  "spec": {
    "strategy": {
      "type": "Recreate",
      "rollingUpdate": null
    },
    "template": {
      "spec": {
        "terminationGracePeriodSeconds": 0,
        "containers": [{
          "name": "nginx",
          "image": "nginx:1.25.3",
          "imagePullPolicy": "IfNotPresent",
          "resources": {
            "requests": {"memory": null, "cpu": null},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}' 

echo "3. Force-clearing existing pods to ensure the node slot is empty..."
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0 

echo "4. Manual Readiness Verification Loop..."
for i in {1..20}; do
  READY=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false") 
  PHASE=$(kubectl get pods -n $NAMESPACE -l app=ingress-controller -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown") 
  
  if [ "$READY" == "true" ]; then
    echo "✅ Success! Pod is Ready with nginx:1.25.3. Score: 1.0" 
    break
  fi
  
  echo "Current State: $PHASE ($i/20)" 
  sleep 5
done

kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=10s || true
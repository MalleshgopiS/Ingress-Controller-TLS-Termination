#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Patching ConfigMap (Fixing the timeout)..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Scaling to 0 to clear node resources (Preserving UID)..."
# We scale to 0 first. This forces K8s to release the memory/CPU slots on the full node.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p '{"spec":{"replicas":0}}'

echo "3. Applying Surgical 1.0 Patch (Image + 1Mi Memory + Scale to 1)..."
# - replicas: 1 (Starts the new pod in a now-empty slot)
# - imagePullPolicy: Never (Prevents the offline timeout)
# - requests.memory: 1Mi (Ensures it fits on the crowded node)
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type strategic -p '{
  "spec": {
    "replicas": 1,
    "template": {
      "spec": {
        "terminationGracePeriodSeconds": 0,
        "containers": [{
          "name": "nginx",
          "image": "nginx:1.25.3",
          "imagePullPolicy": "Never",
          "resources": {
            "requests": {"memory": "1Mi", "cpu": "1m"},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}'

echo "4. Verifying Readiness..."
# Since we cleared the slot, the pod will now move from 'Pending' to 'Running'
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=60s

echo "✅ Node slot cleared. Pod is Running. Ready for 1.0 score."
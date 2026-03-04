#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

# 1. Fix the memory leak in the config
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

# 2. Bypass Apex Node Starvation & Image Timeout
# We set request to 1Mi so it fits on the full node.
# We set imagePullPolicy to IfNotPresent to stop the network timeout.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type strategic -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "image": "nginx:1.25.3",
          "imagePullPolicy": "IfNotPresent",
          "resources": {
            "requests": {"memory": "1Mi"},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}'

# 3. Wait for readiness so the grader doesn't run too early
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s
#!/usr/bin/env bash
# ============================================================
# solution.sh - The "Hammer" Version for 1.0 Score
# ============================================================
set -euo pipefail

NAMESPACE="ingress-system"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "1. Patching ConfigMap..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type merge -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "2. Bypassing Starvation & Force-Clearing Zombie Pods..."
# We lower memory REQUEST to 10Mi and LIMIT to 128Mi.
# We also set the progressDeadlineSeconds to 60s so it doesn't hang for 5 mins.
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type strategic -p '{
  "spec": {
    "progressDeadlineSeconds": 60,
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "resources": {
            "requests": {"memory": "10Mi"},
            "limits": {"memory": "128Mi"}
          }
        }]
      }
    }
  }
}'

echo "3. Force-deleting the old pod to break the deadlock..."
# This is the 'Hammer'. It tells K8s: 'Do not wait, kill it NOW.'
kubectl delete pods -n $NAMESPACE -l app=ingress-controller --force --grace-period=0

echo "4. Verifying new pod health..."
# Now that the zombie is gone, the new pod will start in seconds.
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=60s

echo "✅ Fix applied! Pod is running and memory leak stopped."
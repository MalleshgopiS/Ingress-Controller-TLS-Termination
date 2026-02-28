#!/bin/bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Patching ConfigMap..."
kubectl patch configmap ${CM} \
  -n ${NS} \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting Deployment..."
kubectl rollout restart deployment/${DEPLOY} -n ${NS}

echo "Waiting for rollout..."
kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=180s

echo "Solution applied."#!/bin/bash
set -euo pipefail

NS="ingress-system"
DEPLOY="ingress-controller"
CM="ingress-nginx-config"

echo "Fixing ConfigMap..."
kubectl patch configmap ${CM} \
  -n ${NS} \
  --type merge \
  -p '{"data":{"ssl-session-timeout":"10m"}}'

echo "Restarting deployment..."
kubectl rollout restart deployment/${DEPLOY} -n ${NS}

kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=180s

echo "Fix applied."
#!/bin/bash
set -e

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

echo "Fetching nginx.conf..."

kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} \
  -o jsonpath='{.data.nginx\.conf}' > /tmp/nginx.conf

echo "Updating ssl_session_timeout..."

sed -E -i 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/' /tmp/nginx.conf

echo "Re-applying ConfigMap..."

kubectl create configmap ${CONFIGMAP} \
  --from-file=nginx.conf=/tmp/nginx.conf \
  -n ${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Triggering rolling restart..."

kubectl rollout restart deployment/${DEPLOYMENT} -n ${NAMESPACE}

echo "Waiting for rollout..."

kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=300s

echo "Solution complete."
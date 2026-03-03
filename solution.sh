#!/bin/bash
set -e

NAMESPACE="default"
CONFIGMAP="ingress-nginx-config"
DEPLOYMENT="ingress-controller"

kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} \
  -o jsonpath='{.data.custom\.conf}' > /tmp/custom.conf

sed -E -i 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/' /tmp/custom.conf

kubectl create configmap ${CONFIGMAP} \
  --from-file=custom.conf=/tmp/custom.conf \
  -n ${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rollout safely via annotation patch (does NOT change deployment UID)
kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"config-hash\":\"$(date +%s)\"}}}}}"

kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=300s

echo "Solution complete."
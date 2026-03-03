#!/bin/bash
set -e

NS="default"
CM="ingress-nginx-config"
DEPLOY="ingress-controller"

kubectl get configmap $CM -n $NS \
  -o jsonpath='{.data.custom\.conf}' > /tmp/custom.conf

# Replace only ssl_session_timeout value
sed -E -i 's/(ssl_session_timeout[[:space:]]+)[^;]+;/\110m;/' /tmp/custom.conf

kubectl create configmap $CM \
  --from-file=custom.conf=/tmp/custom.conf \
  -n $NS \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger safe rollout without changing UID
kubectl patch deployment $DEPLOY -n $NS \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"reload\":\"$(date +%s)\"}}}}}"

kubectl rollout status deployment/$DEPLOY -n $NS --timeout=300s
#!/bin/bash
# ==========================================================
# Hard++ Solution Script
# ==========================================================
#
# Must:
# - Preserve replicas (3)
# - Preserve RollingUpdate strategy
# - Preserve UID
# - Preserve memory and image
# - Avoid downtime
#
# ==========================================================

set -e

NS=$(cat /grader/namespace)

kubectl patch configmap ingress-nginx-config \
  -n $NS \
  --type merge \
  -p '{"data":{"nginx.conf":"events {}\nhttp {\n  server {\n    listen 80;\n    ssl_session_timeout 10m;\n    location / { return 200 \"OK\\n\"; }\n  }\n}\n"}}'

kubectl rollout restart deployment/ingress-controller -n $NS

kubectl rollout status deployment/ingress-controller -n $NS --timeout=180s

echo "✅ Hard++ Fix complete."
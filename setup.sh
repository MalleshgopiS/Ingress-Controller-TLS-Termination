#!/bin/bash
set -e

###############################################################################
# Ingress Controller TLS Termination (Hard++)
#
# This script prepares the initial state.
#
# The nginx configuration intentionally contains:
#     ssl_session_timeout 0m;
#
# This value:
#   - Is VALID for nginx startup (pods become Ready)
#   - Is INVALID per task regex requirement:
#         ^[1-9][0-9]*(s|m|h|d)$
#
# The student must change ONLY this value.
###############################################################################

echo "Creating namespace..."
kubectl create namespace ingress-system 2>/dev/null || true

echo "Creating ConfigMap..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: ingress-system
data:
  nginx.conf: |
    events {}

    http {
      server {
        listen 80;

        # INVALID per task regex (zero not allowed)
        ssl_session_timeout 0m;

        location / {
          return 200 "OK\n";
        }
      }
    }
EOF

echo "Creating Service..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
  namespace: ingress-system
spec:
  selector:
    app: ingress-controller
  ports:
    - port: 80
      targetPort: 80
EOF

echo "Creating Deployment..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: ingress-system
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: ingress-controller
  template:
    metadata:
      labels:
        app: ingress-controller
    spec:
      containers:
        - name: nginx
          image: nginx:1.25.3
          ports:
            - containerPort: 80
          resources:
            limits:
              memory: "128Mi"
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: nginx-config
          configMap:
            name: ingress-nginx-config
EOF

echo "Waiting for deployment rollout..."

kubectl rollout status deployment/ingress-controller \
  -n ingress-system --timeout=300s

mkdir -p /grader

kubectl get deployment ingress-controller -n ingress-system \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
#!/bin/bash
set -e

###############################################################################
# Ingress Controller TLS Termination (Hard++)
# -----------------------------------------------------------------------------
# Nebula Environment Setup Script
#
# This script prepares the initial cluster state for the task.
#
# Namespace:
#   ingress-system
#
# Resources Created:
#   - ConfigMap: ingress-nginx-config
#   - Service: ingress-controller
#   - Deployment: ingress-controller
#
# Deployment Configuration:
#   - Replicas: 3
#   - Strategy: RollingUpdate
#       maxUnavailable: 0
#       maxSurge: 1
#   - Image: nginx:1.25.3
#   - Memory limit: 128Mi
#
# Important:
#   The nginx.conf contains:
#
#       ssl_session_timeout 00m;
#
#   This value is:
#     - VALID for nginx startup (pods will become Ready)
#     - INVALID per task regex requirement:
#           ^[1-9][0-9]*(s|m|h|d)$
#
#   The student must modify ONLY this value to a valid non-zero duration.
#
# Constraints enforced by grader:
#   - Deployment UID must remain unchanged
#   - Replicas must remain 3
#   - maxUnavailable must remain 0
#   - Image must remain nginx:1.25.3
#   - Memory limit must remain 128Mi
#   - HTTP 200 must be served
#   - Restart counts must remain stable
#
# Nebula Compatibility:
#   - No internet pulls required
#   - No external images used
#   - Fully compatible with k3s snapshot mode
#   - Works with concurrent arena runs
###############################################################################

echo "Creating namespace..."
kubectl create namespace ingress-system 2>/dev/null || true

echo "Creating ConfigMap with logically invalid ssl_session_timeout..."

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

        # Intentionally invalid per task regex (leading zero)
        ssl_session_timeout 00m;

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

echo "Creating Deployment (3 replicas, maxUnavailable=0)..."

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

echo "Saving original Deployment UID for grader..."

mkdir -p /grader

kubectl get deployment ingress-controller -n ingress-system \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete. Cluster ready for task execution."
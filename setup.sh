#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Setup Script: Ingress Controller TLS Termination (Broken)
# ------------------------------------------------------------
#
# This script prepares the initial broken Kubernetes environment.
#
# It performs the following:
#
#   1. Creates namespace: ingress-system
#   2. Grants ubuntu-user RBAC access in that namespace
#   3. Creates a ConfigMap containing:
#        ssl-session-timeout: "0"
#      (This is intentionally invalid — timeout must be non-zero)
#   4. Creates a Service exposing nginx on port 80
#   5. Deploys nginx:1.25.3 with memory limit 128Mi
#   6. Mounts the ConfigMap as environment variable
#   7. Waits until the Deployment becomes Ready
#   8. Stores the original Deployment UID for grading
#
# IMPORTANT CONSTRAINTS (enforced by grader):
#   - Deployment must NOT be recreated
#   - Memory limit must remain 128Mi
#   - Image must remain nginx:1.25.3
#
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

############################################
# RBAC for ubuntu-user
############################################
echo "Granting ubuntu-user access..."

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ubuntu-user-admin
  namespace: ${NS}
rules:
- apiGroups: [""]
  resources: ["configmaps","pods","services"]
  verbs: ["get","list","watch","create","update","patch","delete"]
- apiGroups: ["apps"]
  resources: ["deployments","replicasets"]
  verbs: ["get","list","watch","create","update","patch","delete"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ubuntu-user-admin-binding
  namespace: ${NS}
subjects:
- kind: ServiceAccount
  name: ubuntu-user
  namespace: default
roleRef:
  kind: Role
  name: ubuntu-user-admin
  apiGroup: rbac.authorization.k8s.io
EOF

############################################
# Broken ConfigMap
############################################
echo "Creating broken ConfigMap..."

kubectl apply -n "$NS" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

############################################
# Service
############################################
echo "Creating service..."

kubectl apply -n "$NS" -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
spec:
  selector:
    app: ingress-controller
  ports:
  - port: 80
    targetPort: 80
EOF

############################################
# Deployment
############################################
echo "Creating deployment..."

kubectl apply -n "$NS" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
spec:
  replicas: 1
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
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
        env:
        - name: SSL_SESSION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              name: ingress-nginx-config
              key: ssl-session-timeout
EOF

############################################
# Wait for Ready
############################################
echo "Waiting for deployment readiness..."

kubectl wait deployment ingress-controller \
  -n "$NS" \
  --for=condition=Available \
  --timeout=300s

############################################
# Save Deployment UID
############################################
mkdir -p /grader

kubectl get deploy ingress-controller \
  -n "$NS" \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Setup Script: Ingress Controller TLS Termination (Broken State)
# ------------------------------------------------------------
#
# This script prepares the initial broken Kubernetes environment.
#
# It performs the following:
#   1. Creates the namespace `ingress-system`
#   2. Grants ubuntu-user RBAC permissions
#   3. Creates a broken ConfigMap containing invalid ssl_session_timeout (0)
#   4. Creates a Service exposing nginx on port 80
#   5. Deploys nginx:1.25.3 with memory limit 128Mi
#   6. Mounts the ConfigMap into nginx configuration
#   7. Waits for the pod to become Ready
#   8. Saves the original Deployment UID for grader validation
#
# The Deployment must NOT be recreated during the solution.
# Only the ConfigMap should be fixed.
#
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl get ns $NS >/dev/null 2>&1 || kubectl create namespace $NS

############################################
# RBAC
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

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  default.conf: |
    server {
      listen 80;
      location / {
        return 200 "OK";
      }
      ssl_session_timeout 0;
    }
EOF

############################################
# Service
############################################
kubectl apply -n $NS -f - <<EOF
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
kubectl apply -n $NS -f - <<EOF
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
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
EOF

echo "Waiting for pod Ready..."
kubectl wait pod -n $NS -l app=ingress-controller \
  --for=condition=Ready --timeout=300s

mkdir -p /grader
kubectl get deploy ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
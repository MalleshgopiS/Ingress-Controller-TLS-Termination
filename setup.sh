#!/usr/bin/env bash
#
# ------------------------------------------------------------
# Setup Script: Ingress Controller TLS Termination Task
# ------------------------------------------------------------
#
# Creates:
#   - Namespace ingress-system
#   - RBAC for ubuntu-user
#   - Broken ConfigMap (ssl-session-timeout: "0")
#   - Service
#   - Deployment (nginx:1.25.3, 128Mi memory)
#
# Saves original Deployment UID for grader validation.
#
# Nebula-safe: does NOT use condition=Available
# ------------------------------------------------------------

set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

############################################################
# RBAC
############################################################
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

############################################################
# Broken ConfigMap
############################################################
echo "Creating broken ConfigMap..."

kubectl apply -n "$NS" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

############################################################
# Service
############################################################
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

############################################################
# Deployment
############################################################
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
EOF

############################################################
# Nebula-Safe Wait (NO condition=Available)
############################################################
echo "Waiting for deployment readyReplicas == 1..."

for i in {1..120}; do
  READY=$(kubectl get deploy ingress-controller -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

  if [[ "$READY" == "1" ]]; then
    echo "Deployment is ready."
    break
  fi

  sleep 2
done

############################################################
# Save original UID
############################################################
echo "Saving original UID..."

mkdir -p /grader

kubectl get deployment ingress-controller \
  -n "$NS" \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
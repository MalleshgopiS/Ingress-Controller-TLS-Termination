#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

# -------------------------------------------------------
# RBAC
# -------------------------------------------------------
echo "Granting ubuntu-user access to ingress-system namespace..."

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ubuntu-user-admin
  namespace: $NS
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["*"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ubuntu-user-admin-binding
  namespace: $NS
subjects:
- kind: User
  name: ubuntu
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ubuntu-user-admin
  apiGroup: rbac.authorization.k8s.io
EOF

# -------------------------------------------------------
# Broken ConfigMap
# -------------------------------------------------------
echo "Creating broken ConfigMap..."

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

# -------------------------------------------------------
# Deployment
# -------------------------------------------------------
echo "Creating deployment..."

kubectl apply -n $NS -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  labels:
    app: ingress-controller
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
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
          requests:
            memory: "128Mi"
EOF

# -------------------------------------------------------
# WAIT FOR POD (NOT ROLLOUT)
# -------------------------------------------------------
echo "Waiting for pod creation..."

until kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  sleep 2
done

POD=$(kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}')

echo "Waiting for pod to be Running..."

kubectl wait --for=condition=Ready pod/$POD \
  -n $NS --timeout=180s

# small stabilization delay (important for Nebula)
sleep 5

# -------------------------------------------------------
# Save Deployment UID for grader
# -------------------------------------------------------
echo "Saving original Deployment UID..."

mkdir -p /grader

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."
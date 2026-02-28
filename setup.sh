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
# Broken ConfigMap (TASK TARGET)
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

        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
EOF

# -------------------------------------------------------
# Wait for Pod creation
# -------------------------------------------------------
echo "Waiting for pod object..."

until kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  sleep 2
done

# -------------------------------------------------------
# Wait for rollout
# -------------------------------------------------------
echo "Waiting for deployment readiness..."

kubectl rollout status deployment ingress-controller \
  -n $NS --timeout=180s

# stabilization wait (important for Nebula)
sleep 5

# -------------------------------------------------------
# Save UID for grader
# -------------------------------------------------------
echo "Saving original Deployment UID..."

mkdir -p /grader

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."
#!/usr/bin/env bash
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
  ssl-session-timeout: "0"
EOF

############################################
# Service (CRITICAL FIX)
############################################
echo "Creating service..."

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
# Deployment (stable rollout version)
############################################
echo "Creating deployment..."

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
        image: nginx:1.25
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"

        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5

        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 10
EOF

############################################
# WAIT FOR INITIAL READY STATE
############################################
echo "Waiting for deployment readiness..."

kubectl rollout status deployment ingress-controller \
  -n $NS \
  --timeout=180s

############################################
# Save UID for grader
############################################
echo "Saving original UID..."

kubectl get deployment ingress-controller \
  -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "✅ Setup complete."
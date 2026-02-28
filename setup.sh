#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

###############################################################################
# Grant ubuntu-user access to ingress-system namespace
###############################################################################
echo "Granting ubuntu-user access to $NS namespace..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ubuntu-user-admin
  namespace: ${NS}
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
EOF

cat <<EOF | kubectl apply -f -
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

###############################################################################
# Create BROKEN (but runnable) ConfigMap
# ssl-session-timeout intentionally wrong ("0")
###############################################################################
echo "Creating broken ConfigMap..."

kubectl apply -n "$NS" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"

  default.conf: |
    server {
        listen 80;
        location / {
            return 200 "nginx running";
        }
    }
EOF

###############################################################################
# Create Deployment (grader depends on exact values)
###############################################################################
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
        image: nginx:1.25
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

###############################################################################
# Wait until pod object exists (not readiness)
###############################################################################
echo "Waiting for pod object to be created..."

timeout 120 bash -c '
until kubectl get pods -n '"$NS"' -l app=ingress-controller \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null | grep -q .; do
  sleep 2
done
'

###############################################################################
# Save original Deployment UID (required by grader)
###############################################################################
echo "Saving original Deployment UID..."

mkdir -p /grader

kubectl get deployment ingress-controller \
  -n "$NS" \
  -o jsonpath="{.metadata.uid}" > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."
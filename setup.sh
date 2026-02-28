#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

# -------------------------------------------------------
# RBAC (required for ubuntu user)
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
  default.conf: |
    server {
        listen 80;
        server_name _;
        location / {
            return 200 "nginx running";
        }
    }
EOF

# -------------------------------------------------------
# Deployment (LOGIC UNCHANGED)
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
          initialDelaySeconds: 3
          periodSeconds: 3

        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d   # ✅ FIXED (directory mount)

      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
EOF

# -------------------------------------------------------
# Wait for Pod to exist
# -------------------------------------------------------
echo "Waiting for pod object..."

until kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  sleep 2
done

# -------------------------------------------------------
# Wait for Deployment to be Ready
# -------------------------------------------------------
echo "Waiting for deployment readiness..."

kubectl rollout status deployment ingress-controller \
  -n $NS --timeout=180s

# small stabilization wait (Nebula specific)
sleep 5

# -------------------------------------------------------
# Save original UID for grader
# -------------------------------------------------------
echo "Saving original Deployment UID..."

mkdir -p /grader

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."
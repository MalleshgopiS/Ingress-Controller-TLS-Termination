#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

# -------------------------------------------------------
# Grant ubuntu user access (REQUIRED BY APEX ENV)
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
# Create BROKEN ConfigMap (ssl-session-timeout = "0")
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
        listen 80 default_server;
        server_name _;
        location / {
            return 200 "nginx running";
            add_header Content-Type text/plain;
        }
    }
EOF

# -------------------------------------------------------
# Deployment (DO NOT CHANGE LOGIC)
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

        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf

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

      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
EOF

# -------------------------------------------------------
# WAIT FOR POD OBJECT (avoid race condition)
# -------------------------------------------------------
echo "Waiting for pod object to be created..."

until kubectl get pods -n $NS -l app=ingress-controller \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; do
  sleep 2
done

# -------------------------------------------------------
# Wait for deployment readiness (CRITICAL FIX)
# -------------------------------------------------------
echo "Waiting for deployment readiness..."

kubectl rollout status deployment ingress-controller \
  -n $NS --timeout=180s

# small stabilization wait (Nebula snapshot env fix)
sleep 5

# -------------------------------------------------------
# Save ORIGINAL UID for grader check
# -------------------------------------------------------
echo "Saving original Deployment UID..."

kubectl get deployment ingress-controller -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."



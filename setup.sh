#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "Creating namespace..."
kubectl get ns $NS >/dev/null 2>&1 || kubectl create ns $NS

###############################################################################
# RBAC
###############################################################################
echo "Granting ubuntu-user access..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ubuntu-user-admin
  namespace: ${NS}
rules:
- apiGroups: ["", "apps"]
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
# Broken ConfigMap
###############################################################################
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
      location / {
        return 200 "nginx running";
      }
    }
EOF

###############################################################################
# Deployment (CRITICAL FIXES)
###############################################################################
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
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"

        # ⭐ FIX 1 — readiness probe (ROLL OUT FIX)
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3

        # ⭐ FIX 2 — liveness probe (stability check)
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf

      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
EOF

###############################################################################
# Wait until READY (IMPORTANT FOR QUALITY REVIEW)
###############################################################################
echo "Waiting for deployment readiness..."

kubectl rollout status deployment ingress-controller \
  -n $NS \
  --timeout=180s

###############################################################################
# Save ORIGINAL UID (grader requirement)
###############################################################################
echo "Saving original Deployment UID..."

mkdir -p /grader

kubectl get deployment ingress-controller \
  -n $NS \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

chmod 444 /grader/original_uid

echo "Setup complete."


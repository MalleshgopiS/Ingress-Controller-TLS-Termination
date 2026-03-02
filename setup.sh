#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"

echo "======================================"
echo "Nebula Setup Starting"
echo "======================================"

############################################################
# Namespace (SAFE APPLY)
############################################################
kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

############################################################
# ConfigMap (YOUR ORIGINAL BEHAVIOR)
############################################################
echo "Applying nginx configmap..."

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "10m"
EOF

############################################################
# Deployment
# NOTHING REMOVED — ONLY ADDED MOUNT SUPPORT
############################################################
echo "Deploying ingress controller..."

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
        ports:
        - containerPort: 80

        resources:
          limits:
            memory: "128Mi"

        ####################################################
        # ✅ ADDED (REQUIRED FOR APEX OBSERVABLE FIX)
        ####################################################
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/session.conf
          subPath: session.conf

      ####################################################
      # ✅ ADDED VOLUME
      ####################################################
      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
          items:
          - key: ssl-session-timeout
            path: session.conf
EOF

############################################################
# Service (UNCHANGED LOGIC)
############################################################
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

############################################################
# ✅ CRITICAL ADDITION — CONVERGENCE WAIT
############################################################
echo "Waiting for deployment rollout..."

kubectl rollout status deployment/ingress-controller \
  -n $NS \
  --timeout=180s || true

echo "======================================"
echo "Setup Completed"
echo "======================================"
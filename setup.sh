#!/bin/bash
# ============================================================
# Setup Script
# Initializes Kubernetes resources for TLS session timeout task.
#
# Creates:
#   - Namespace ingress-system
#   - ConfigMap ingress-nginx-config (with invalid value "0")
#   - Service ingress-controller
#   - Deployment ingress-controller (nginx:1.25.3, 128Mi)
#
# Stores original Deployment UID in /grader/original_uid
# ============================================================

set -e

NAMESPACE="ingress-system"

kubectl create namespace $NAMESPACE || true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: ingress-system
data:
  ssl-session-timeout: "0"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ingress-controller
  namespace: ingress-system
spec:
  selector:
    app: ingress-controller
  ports:
    - port: 80
      targetPort: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-controller
  namespace: ingress-system
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
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/conf.d
      volumes:
        - name: nginx-config
          configMap:
            name: ingress-nginx-config
EOF

kubectl rollout status deployment/ingress-controller -n $NAMESPACE --timeout=120s

mkdir -p /grader
kubectl get deployment ingress-controller -n $NAMESPACE -o jsonpath='{.metadata.uid}' > /grader/original_uid
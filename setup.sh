#!/bin/bash
set -e

NAMESPACE="ingress-system"

echo "Creating namespace..."
kubectl create namespace $NAMESPACE || true

echo "Creating broken ConfigMap..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
  namespace: ingress-system
data:
  ssl-session-timeout: "0"
EOF

echo "Creating Service..."

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

echo "Creating Deployment..."

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

echo "Waiting for deployment rollout..."
kubectl rollout status deployment/ingress-controller -n $NAMESPACE --timeout=120s

echo "Saving original UID..."
kubectl get deployment ingress-controller -n $NAMESPACE -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
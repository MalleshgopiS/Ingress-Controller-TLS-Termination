#!/bin/bash
set -e

NAMESPACE="default"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"
SERVICE="ingress-controller"

echo "Creating ConfigMap..."
kubectl create configmap ${CONFIGMAP} \
  --from-literal=nginx.conf='
events {}
http {
  server {
    listen 80;
    ssl_session_timeout 0m;
    location / {
      return 200 "OK";
    }
  }
}
' \
  -n ${NAMESPACE}

echo "Creating Service..."
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE}
spec:
  selector:
    app: ${DEPLOYMENT}
  ports:
  - port: 80
    targetPort: 80
EOF

echo "Creating Deployment..."
kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOYMENT}
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
  selector:
    matchLabels:
      app: ${DEPLOYMENT}
  template:
    metadata:
      labels:
        app: ${DEPLOYMENT}
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.3
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-config
        configMap:
          name: ${CONFIGMAP}
EOF

echo "Waiting for rollout..."
kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=300s

echo "Saving original UID..."
kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
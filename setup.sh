#!/bin/bash
set -e

NAMESPACE="default"
DEPLOYMENT="ingress-controller"
CONFIGMAP="ingress-nginx-config"
SERVICE="ingress-controller"

echo "Creating ConfigMap..."

kubectl apply -n ${NAMESPACE} -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CONFIGMAP}
data:
  custom.conf: |
    server {
        listen 8080;
        ssl_session_timeout 0m;

        location / {
            return 200 "OK";
        }
    }
EOF

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
    targetPort: 8080
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
          limits:
            memory: 128Mi
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 2
          periodSeconds: 3
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/custom.conf
          subPath: custom.conf
      volumes:
      - name: nginx-config
        configMap:
          name: ${CONFIGMAP}
EOF

echo "Waiting for rollout..."

kubectl rollout status deployment/${DEPLOYMENT} -n ${NAMESPACE} --timeout=300s

kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} \
  -o jsonpath='{.metadata.uid}' > /grader/original_uid

echo "Setup complete."
#!/usr/bin/env bash
set -euo pipefail

NS="ingress-system"
DEPLOYMENT="ingress-controller"

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n $NS -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-config
data:
  ssl-session-timeout: "0"
EOF

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
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/session.conf
          subPath: session.conf
      volumes:
      - name: nginx-config
        configMap:
          name: ingress-nginx-config
          items:
          - key: ssl-session-timeout
            path: session.conf
EOF

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

kubectl rollout status deployment/$DEPLOYMENT -n $NS --timeout=180s

#  STORE ORIGINAL UID FOR GRADER
kubectl get deploy $DEPLOYMENT -n $NS \
  -o jsonpath='{.metadata.uid}' > /tmp/original_uid
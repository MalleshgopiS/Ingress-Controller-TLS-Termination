#!/bin/bash
set -e

echo "Injecting ingress TLS memory leak..."

########################################
# BAD TLS CONFIG (was manifests/bad-ingress-config.yaml)
########################################
kubectl patch configmap ingress-nginx-controller \
  -n ingress-nginx \
  --type merge \
  -p '{"data":{
      "ssl-session-cache":"shared:SSL:150m",
      "ssl-session-timeout":"24h"
  }}'

########################################
# REMOVE MEMORY LIMIT
########################################
kubectl patch deployment ingress-nginx-controller \
  -n ingress-nginx \
  --type merge \
  -p '{"spec":{"template":{"spec":{"containers":[
      {"name":"controller","resources":{"requests":{"memory":"128Mi"}}}
  ]}}}}'

########################################
# TLS TRAFFIC GENERATOR
########################################
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tls-traffic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tls-traffic
  template:
    metadata:
      labels:
        app: tls-traffic
    spec:
      containers:
      - name: curl
        image: curlimages/curl
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            curl -k https://bleater.devops.local >/dev/null 2>&1
            sleep 0.2
          done
EOF

########################################
# ALERT RULE (was monitoring/alert-rule.yaml)
########################################
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ingress-memory-alert
  namespace: monitoring
spec:
  groups:
  - name: ingress-alerts
    rules:
    - alert: IngressMemoryHigh
      expr: container_memory_working_set_bytes{pod=~"ingress-nginx-controller.*"} > 400000000
      for: 1m
      labels:
        severity: critical
EOF

########################################

kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

echo "Fault injection complete."
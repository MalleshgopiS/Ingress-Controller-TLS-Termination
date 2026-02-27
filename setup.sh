#!/bin/bash
set -e

echo "Injecting TLS session memory leak..."

kubectl apply -f manifests/bad-ingress-config.yaml
kubectl apply -f manifests/patch-no-limits.yaml
kubectl apply -f manifests/traffic-deployment.yaml

kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

echo "Fault injection complete."
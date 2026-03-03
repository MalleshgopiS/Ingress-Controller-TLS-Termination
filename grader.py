#!/usr/bin/env python3

import subprocess
import re
import sys

NS = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def get(cmd):
    return run(cmd).stdout.strip()

def uid_preserved():
    original = open("/grader/original_uid").read().strip()
    current = get(f"kubectl get deployment {DEPLOYMENT} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original == current

def replicas_ok():
    return get(f"kubectl get deployment {DEPLOYMENT} -n {NS} -o jsonpath='{{.spec.replicas}}'") == "3"

def strategy_ok():
    return get(f"kubectl get deployment {DEPLOYMENT} -n {NS} -o jsonpath='{{.spec.strategy.rollingUpdate.maxUnavailable}}'") == "0"

def memory_ok():
    return get(f"kubectl get deployment {DEPLOYMENT} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'") == "128Mi"

def image_ok():
    return get(f"kubectl get deployment {DEPLOYMENT} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'") == "nginx:1.25.3"

def valid_timeout():
    config = get(f"kubectl get configmap {CONFIGMAP} -n {NS} -o jsonpath='{{.data.custom\\.conf}}'")
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", config)
    if not match:
        return False
    return re.fullmatch(r"[1-9][0-9]*(s|m|h|d)", match.group(1)) is not None

def http_ok():
    pod = get(f"kubectl get pods -l app={DEPLOYMENT} -n {NS} -o jsonpath='{{.items[0].metadata.name}}'")
    result = run(f"kubectl exec {pod} -n {NS} -- curl -s http://localhost:8080")
    return "OK" in result.stdout

checks = [
    uid_preserved(),
    replicas_ok(),
    strategy_ok(),
    memory_ok(),
    image_ok(),
    valid_timeout(),
    http_ok()
]

if all(checks):
    print("SUCCESS")
    sys.exit(0)
else:
    print("FAILURE")
    sys.exit(1)
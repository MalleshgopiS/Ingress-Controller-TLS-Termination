#!/usr/bin/env python3

"""
Grader for Ingress Controller TLS Termination Task

Validates:

1. Setup integrity (original UID saved)
2. Deployment UID unchanged
3. Replicas remain 3
4. RollingUpdate maxUnavailable remains 0
5. Memory limit remains 128Mi
6. Image remains nginx:1.25.3
7. ssl_session_timeout matches regex ^[1-9][0-9]*(s|m|h|d)$
8. nginx.conf structure preserved
9. Rollout successful
10. All replicas Ready
11. HTTP 200 served from Service
"""

import subprocess
import re
import sys

NAMESPACE = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"

def run(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def setup_integrity():
    try:
        with open("/grader/original_uid") as f:
            return bool(f.read().strip())
    except:
        return False

def uid_preserved():
    original = open("/grader/original_uid").read().strip()
    current = run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.metadata.uid}}'")
    return original == current

def replicas_preserved():
    return run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.replicas}}'") == "3"

def strategy_preserved():
    return run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.strategy.rollingUpdate.maxUnavailable}}'") == "0"

def memory_preserved():
    return run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'") == "128Mi"

def image_preserved():
    return run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.template.spec.containers[0].image}}'") == "nginx:1.25.3"

def valid_timeout():
    config = run(f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} -o jsonpath='{{.data.nginx\\.conf}}'")
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", config)
    if not match:
        return False
    return re.fullmatch(r"[1-9][0-9]*(s|m|h|d)", match.group(1)) is not None

def config_preserved():
    config = run(f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} -o jsonpath='{{.data.nginx\\.conf}}'")
    required = ["events", "http", "server", "listen 80", "location /"]
    return all(fragment in config for fragment in required)

def rollout_successful():
    return subprocess.run(
        f"kubectl rollout status deployment/{DEPLOYMENT} -n {NAMESPACE} --timeout=120s",
        shell=True
    ).returncode == 0

def all_ready():
    return run(f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.status.readyReplicas}}'") == "3"

def http_200():
    cmd = f"kubectl run curl-test --rm -i --restart=Never --image=nginx:1.25.3 -n {NAMESPACE} -- curl -s -o /dev/null -w '%{{http_code}}' http://{DEPLOYMENT}"
    return run(cmd) == "200"

checks = [
    setup_integrity(),
    uid_preserved(),
    replicas_preserved(),
    strategy_preserved(),
    memory_preserved(),
    image_preserved(),
    valid_timeout(),
    config_preserved(),
    rollout_successful(),
    all_ready(),
    http_200()
]

if all(checks):
    print("SUCCESS")
    sys.exit(0)
else:
    print("FAILURE")
    sys.exit(1)
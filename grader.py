#!/usr/bin/env python3
"""
Nebula Hard++ Grader

Validates:
1. Deployment UID unchanged
2. Replicas remain 3
3. RollingUpdate maxUnavailable = 0
4. Memory limit = 128Mi
5. Image = nginx:1.25.3
6. ssl_session_timeout matches required regex
7. Only ssl_session_timeout was modified
8. Service responds with HTTP 200
"""

import subprocess
import re
import sys
import json

NS = "default"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def get(cmd):
    return run(cmd).stdout.strip()

def uid_preserved():
    """Ensure Deployment was not recreated."""
    original = open("/grader/original_uid").read().strip()
    current = get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original == current

def replicas_ok():
    """Ensure replicas remain 3."""
    return get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.replicas}}'") == "3"

def strategy_ok():
    """Ensure maxUnavailable remains 0."""
    return get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.strategy.rollingUpdate.maxUnavailable}}'") == "0"

def memory_ok():
    """Ensure memory limit unchanged."""
    return get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'") == "128Mi"

def image_ok():
    """Ensure image unchanged."""
    return get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'") == "nginx:1.25.3"

def valid_timeout():
    """Validate ssl_session_timeout format."""
    config = get(f"kubectl get configmap {CM} -n {NS} -o jsonpath='{{.data.custom\\.conf}}'")
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", config)
    if not match:
        return False
    return re.fullmatch(r"[1-9][0-9]*(s|m|h|d)", match.group(1)) is not None

def only_timeout_modified():
    """
    Ensure no other lines were modified except ssl_session_timeout.
    """
    config = get(f"kubectl get configmap {CM} -n {NS} -o jsonpath='{{.data.custom\\.conf}}'")
    required_fragments = [
        "server {",
        "listen 8080;",
        "location /",
        "return 200 \"healthy\";"
    ]
    return all(fragment in config for fragment in required_fragments)

def http_200():
    """Verify Service returns HTTP 200 using deterministic pod exec."""
    # Wait for ready replicas first
    ready = get(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.status.readyReplicas}}'")
    if ready != "3":
        return False

    # Deterministic pod selection (sorted)
    pods = get(f"kubectl get pods -l app={DEPLOY} -n {NS} -o jsonpath='{{.items[*].metadata.name}}'")
    pod_list = sorted(pods.split())
    if not pod_list:
        return False

    pod = pod_list[0]

    result = run(f"kubectl exec {pod} -n {NS} -- curl -s -o /dev/null -w '%{{http_code}}' http://localhost:8080")
    return result.stdout.strip() == "200"

checks = {
    "uid_preserved": uid_preserved(),
    "replicas_ok": replicas_ok(),
    "strategy_ok": strategy_ok(),
    "memory_ok": memory_ok(),
    "image_ok": image_ok(),
    "valid_timeout": valid_timeout(),
    "only_timeout_modified": only_timeout_modified(),
    "http_200": http_200(),
}

score = sum(checks.values()) / len(checks)

print(json.dumps({
    "score": score,
    "subscores": checks
}))

sys.exit(0 if score == 1.0 else 1)
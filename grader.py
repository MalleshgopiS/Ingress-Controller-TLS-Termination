#!/usr/bin/env python3
"""
Grader for Ingress Controller TLS Session Timeout task.

This grader verifies:
1. Deployment UID preserved
2. Image preserved
3. Memory limit preserved
4. ConfigMap contains valid non-zero duration
5. Deployment is Available
6. HTTP endpoint returns 200
"""

import subprocess
import json
import re
import time
import socket

NAMESPACE = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"

def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()

def wait_for_http(timeout=30):
    start = time.time()
    while time.time() - start < timeout:
        try:
            code = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
            if code == "200":
                return True
        except Exception:
            pass
        time.sleep(1)
    return False

results = {}

try:
    # UID preserved
    original_uid = open("/grader/original_uid").read().strip()
    current_uid = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
        "-o jsonpath='{.metadata.uid}'"
    )
    results["uid_preserved"] = original_uid == current_uid

    # Image preserved
    image = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    results["image_preserved"] = image == "nginx:1.25.3"

    # Memory preserved
    memory = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    results["memory_preserved"] = memory == "128Mi"

    # Valid timeout (any positive integer + unit)
    timeout_value = run(
        f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    results["valid_timeout"] = bool(
        re.match(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", timeout_value)
    )

    # Deployment Available
    available = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
        "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
    )
    results["deployment_available"] = available == "True"

    # HTTP test with proper port-forward cleanup
    pf = subprocess.Popen(
        f"kubectl port-forward svc/{DEPLOYMENT} 18080:80 -n {NAMESPACE}",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(3)
    results["nginx_serving"] = wait_for_http()

    pf.terminate()
    pf.wait(timeout=5)

except Exception as e:
    results["error"] = str(e)

# Strict scoring: ALL must pass
score = 1.0 if all(results.values()) else 0.0

print(json.dumps({
    "score": score,
    "results": results
}))
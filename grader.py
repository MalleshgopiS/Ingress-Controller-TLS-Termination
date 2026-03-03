#!/usr/bin/env python3
"""
Grader for TLS Session Timeout Fix Task.

Validation Criteria:

1. Deployment UID unchanged
2. Image remains nginx:1.25.3
3. Memory remains 128Mi
4. ConfigMap contains valid non-zero nginx duration
5. Deployment condition Available=True
6. HTTP endpoint returns 200
"""

import subprocess
import json
import re
import time

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
    original_uid = open("/grader/original_uid").read().strip()
    current_uid = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.metadata.uid}}'"
    )
    results["uid_preserved"] = original_uid == current_uid

    image = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.template.spec.containers[0].image}}'"
    )
    results["image_preserved"] = image == "nginx:1.25.3"

    memory = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'"
    )
    results["memory_preserved"] = memory == "128Mi"

    timeout_value = run(
        f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} -o jsonpath='{{.data.ssl-session-timeout}}'"
    )

    # Accept integer + unit (nginx duration format)
    results["valid_timeout"] = bool(
        re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout_value)
    )

    available = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
        "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
    )
    results["deployment_available"] = available == "True"

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

score = 1.0 if all(results.values()) else 0.0

print(json.dumps({
    "score": score,
    "results": results
}))
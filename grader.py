#!/usr/bin/env python3
"""
Grader for: Ingress Controller TLS Termination

This grader validates that the candidate correctly fixes the TLS session
timeout misconfiguration while preserving the integrity of the Deployment.

The following checks are performed:

1. Deployment UID is preserved
   - Ensures the Deployment was not deleted or recreated.

2. Memory limit remains exactly 128Mi
   - Ensures resource constraints were not modified.

3. Container image remains nginx:1.25.3
   - Ensures the base image was not changed.

4. ssl-session-timeout is a valid non-zero nginx duration
   - Must match: ^[1-9][0-9]*(s|m|h|d|w|M|y)$

5. Deployment becomes Ready
   - readyReplicas == 1

6. Nginx serves HTTP 200 responses
   - Verified via port-forward and curl

7. Container restart count remains stable
   - Ensures no crash loops after the fix

Final Score:
    Mean of all 7 binary checks (0.0 to 1.0)

Full Score (1.0) requires all checks to pass.
"""

import subprocess
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


class GradeResult:
    def __init__(self, score, subscores, weights, feedback=""):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback


def run(cmd):
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=300, interval=5):
    """
    Wait up to 5 minutes for Kubernetes readiness.
    """
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def nginx_check():
    """
    Port-forward service and verify nginx returns HTTP 200.
    Retry for up to 60 seconds to handle slow container warmup.
    """
    pf = subprocess.Popen(
        f"kubectl port-forward -n {NS} svc/{DEPLOY} 18080:80",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(5)

    ok = False
    for _ in range(12):
        code = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
        if code == "200":
            ok = True
            break
        time.sleep(5)

    pf.terminate()
    return ok


def grade(task_dir=None):

    # Initial stabilization for Nebula snapshot environments
    time.sleep(25)

    subscores = {}
    weights = {}

    # 1. UID preserved
    original_uid = run("cat /grader/original_uid")
    current_uid = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    subscores["uid_preserved"] = original_uid == current_uid
    weights["uid_preserved"] = 1

    # 2. Memory preserved
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1

    # 3. Image preserved
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1

    # 4. Valid timeout format
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )
    weights["valid_timeout"] = 1

    # 5. Deployment ready
    def ready():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        ) == "1"

    subscores["deployment_ready"] = wait_until(ready)
    weights["deployment_ready"] = 1

    # 6. HTTP 200
    subscores["nginx_serving"] = nginx_check()
    weights["nginx_serving"] = 1

    # 7. Restart stable
    pod = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )

    restart_stable = False
    if pod:
        before = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        time.sleep(60)
        after = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        restart_stable = before == after

    subscores["restart_stable"] = restart_stable
    weights["restart_stable"] = 1

    total = len(subscores)
    passed = sum(1 for v in subscores.values() if v)
    score = passed / total

    feedback = f"{passed}/{total} checks passed."

    return GradeResult(score, subscores, weights, feedback)
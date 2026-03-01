#!/usr/bin/env python3
"""
Grader for: Ingress Controller TLS Termination

This grader validates:

1. Deployment UID is preserved (no recreation)
2. Memory limit remains exactly 128Mi
3. Container image remains nginx:1.25.3
4. ssl-session-timeout is a valid non-zero nginx duration
5. Deployment becomes Ready
6. Nginx serves HTTP 200 responses
7. Container restart count remains stable

Final score = mean of all 7 binary checks.
"""

import subprocess
import time
import re


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


class GradeResult:
    """
    Apex-compatible grading result object.

    Required attributes:
        score (float)
        subscores (dict)
        weights (dict)
        feedback (str)
    """

    def __init__(self, score, subscores, weights, feedback=""):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback


def run(cmd):
    """Execute shell command and return output string safely."""
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=180, interval=5):
    """Poll condition function until True or timeout."""
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize():
    """Initial stabilization delay before running checks."""
    time.sleep(25)


def get_pod():
    """Return ingress controller pod name."""
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


def grade(task_dir=None):
    """Run all validation checks and compute final mean score."""

    stabilize()

    subscores = {}
    weights = {}

    # --------------------------------------------------
    # 1. Deployment UID preserved
    # --------------------------------------------------
    original_uid = run("cat /grader/original_uid")
    current_uid = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )

    subscores["uid_preserved"] = (
        bool(original_uid) and original_uid == current_uid
    )
    weights["uid_preserved"] = 1.0

    # --------------------------------------------------
    # 2. Memory limit unchanged
    # --------------------------------------------------
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1.0

    # --------------------------------------------------
    # 3. Image unchanged
    # --------------------------------------------------
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )

    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1.0

    # --------------------------------------------------
    # 4. Valid ssl-session-timeout
    # --------------------------------------------------
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )
    weights["valid_timeout"] = 1.0

    # --------------------------------------------------
    # 5. Deployment Ready
    # --------------------------------------------------
    def ready():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        ) == "1"

    subscores["deployment_ready"] = wait_until(ready)
    weights["deployment_ready"] = 1.0

    # --------------------------------------------------
    # 6. Nginx serving HTTP 200
    # --------------------------------------------------
    nginx_serving = False
    try:
        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(5)
        response = run(
            "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
        )
        pf.terminate()
        nginx_serving = response == "200"
    except Exception:
        nginx_serving = False

    subscores["nginx_serving"] = nginx_serving
    weights["nginx_serving"] = 1.0

    # --------------------------------------------------
    # 7. Restart count stable
    # --------------------------------------------------
    restart_stable = False
    pod = get_pod()

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
    weights["restart_stable"] = 1.0

    # --------------------------------------------------
    # Final Mean Score
    # --------------------------------------------------
    total_weight = sum(weights.values())
    earned = sum(weights[k] for k, v in subscores.items() if v)

    final_score = earned / total_weight if total_weight else 0.0
    feedback = f"{int(earned)}/{int(total_weight)} checks passed."

    return GradeResult(final_score, subscores, weights, feedback)
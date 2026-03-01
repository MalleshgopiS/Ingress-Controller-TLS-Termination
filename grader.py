#!/usr/bin/env python3
"""
Grader for: Ingress Controller TLS Termination

This grader validates that:
1. Deployment UID is preserved (no recreation)
2. Memory limit remains exactly 128Mi
3. Container image remains nginx:1.25.3
4. ssl-session-timeout is valid non-zero nginx duration
5. Deployment becomes Ready
6. Nginx serves HTTP 200 responses
7. Container restart count remains stable

Final score = mean of all 7 checks
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

    Attributes:
        score (float): final mean score (0.0–1.0)
        subscores (dict): individual check results
        feedback (str): optional human-readable summary
    """

    def __init__(self, score, subscores, feedback=""):
        self.score = score
        self.subscores = subscores
        self.feedback = feedback


def run(cmd):
    """Run shell command safely and return output string."""
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=180, interval=5):
    """
    Poll a condition function until True or timeout.
    Used for Kubernetes readiness stabilization.
    """
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize():
    """
    Initial stabilization delay to allow cluster state
    to settle before running validation checks.
    """
    time.sleep(25)


def get_pod():
    """Return ingress controller pod name."""
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


def grade(task_dir=None):
    """
    Execute all validation checks and compute final mean score.
    """

    stabilize()

    subscores = {}

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

    # --------------------------------------------------
    # 2. Memory limit unchanged (128Mi)
    # --------------------------------------------------
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_preserved"] = memory == "128Mi"

    # --------------------------------------------------
    # 3. Image unchanged (nginx:1.25.3)
    # --------------------------------------------------
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_preserved"] = image == "nginx:1.25.3"

    # --------------------------------------------------
    # 4. ssl-session-timeout valid non-zero nginx duration
    # --------------------------------------------------
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )

    # --------------------------------------------------
    # 5. Deployment Ready
    # --------------------------------------------------
    def ready():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        ) == "1"

    subscores["deployment_ready"] = wait_until(ready)

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
        response = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
        pf.terminate()
        nginx_serving = response == "200"
    except Exception:
        nginx_serving = False

    subscores["nginx_serving"] = nginx_serving

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

    # --------------------------------------------------
    # Final Mean Score
    # --------------------------------------------------
    total = len(subscores)
    passed = sum(1 for v in subscores.values() if v)
    final_score = passed / total if total else 0.0

    feedback = f"{passed}/{total} checks passed."

    return GradeResult(final_score, subscores, feedback)
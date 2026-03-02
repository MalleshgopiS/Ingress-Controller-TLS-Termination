#!/usr/bin/env python3
"""
Nebula-compatible grader for:

Ingress Controller TLS Termination

Validates:

1. Deployment UID preserved
2. Memory limit unchanged (128Mi)
3. Image unchanged (nginx:1.25.3)
4. ssl-session-timeout valid
5. Deployment Available
6. nginx serves HTTP 200
7. Restart count stable
"""

import subprocess
import time
import re
import urllib.request

# -----------------------------------------------------------
# Apex compatibility layer (FIXES ModuleNotFoundError)
# -----------------------------------------------------------
try:
    from apex_arena.grading import GradeResult
except Exception:
    # fallback when apex_arena module is unavailable
    class GradeResult(dict):
        def __init__(self, score, subscores):
            super().__init__(score=score, subscores=subscores)


# -----------------------------------------------------------
# Helpers
# -----------------------------------------------------------
def run(cmd: str) -> str:
    """Run shell command safely."""
    try:
        return subprocess.check_output(
            cmd, shell=True, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def wait_until(condition, timeout=180, interval=3):
    """Wait until condition returns True."""
    start = time.time()
    while time.time() - start < timeout:
        if condition():
            return True
        time.sleep(interval)
    return False


# -----------------------------------------------------------
# Validators
# -----------------------------------------------------------
def valid_nginx_duration(value: str) -> bool:
    """
    Validate nginx duration format.

    Supported:
      s, m, h, d, w, M, y
    Example: 10m, 1h, 7d
    """
    if not value:
        return False
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value) is not None


# -----------------------------------------------------------
# Deployment readiness
# -----------------------------------------------------------
def deployment_ready():
    ready = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
    )
    return ready == "True"


def get_running_pod():
    return run(
        "kubectl -n ingress-system get pods "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# -----------------------------------------------------------
# HTTP check
# -----------------------------------------------------------
def nginx_responding():
    try:
        subprocess.Popen(
            "kubectl -n ingress-system port-forward svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(5)

        with urllib.request.urlopen("http://localhost:18080", timeout=5) as r:
            return r.status == 200
    except Exception:
        return False


# -----------------------------------------------------------
# MAIN GRADER
# -----------------------------------------------------------
def grade():

    subscores = {}

    # -----------------------------
    # Wait for deployment stability
    # -----------------------------
    wait_until(deployment_ready, timeout=180, interval=3)

    # -----------------------------
    # UID CHECK
    # -----------------------------
    current_uid = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.metadata.uid}'"
    )

    original_uid = run(
        "test -f /tmp/original_uid && cat /tmp/original_uid"
    )

    subscores["deployment_uid_unchanged"] = (
        bool(original_uid) and current_uid == original_uid
    )

    # -----------------------------
    # MEMORY CHECK
    # -----------------------------
    memory = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_limit_unchanged"] = memory == "128Mi"

    # -----------------------------
    # IMAGE CHECK
    # -----------------------------
    image = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_unchanged"] = image == "nginx:1.25.3"

    # -----------------------------
    # CONFIGMAP VALIDATION
    # -----------------------------
    timeout_value = run(
        "kubectl -n ingress-system get configmap ingress-nginx-config "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    subscores["valid_non_zero_timeout"] = (
        timeout_value != "0" and valid_nginx_duration(timeout_value)
    )

    # -----------------------------
    # POD + RESTART CHECK
    # -----------------------------
    pod = get_running_pod()

    restart_count = "99"
    if pod:
        restart_count = run(
            f"kubectl -n ingress-system get pod {pod} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )

    # allow ≤1 restart (k3s stabilization)
    subscores["restart_count_zero"] = (
        restart_count.isdigit() and int(restart_count) <= 1
    )

    # -----------------------------
    # HTTP CHECK
    # -----------------------------
    subscores["nginx_serving_200"] = nginx_responding()

    # -----------------------------
    # FINAL SCORE
    # -----------------------------
    score = sum(subscores.values()) / len(subscores)

    return GradeResult(score=score, subscores=subscores)


# -----------------------------------------------------------
if __name__ == "__main__":
    result = grade()
    print(result)
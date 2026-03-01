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


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


# --------------------------------------------------
# Apex grading result object
# --------------------------------------------------
class GradeResult:
    def __init__(self, score, subscores, weights, feedback=""):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback


# --------------------------------------------------
# helpers
# --------------------------------------------------
def run(cmd):
    """Execute command safely."""
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=300, interval=5):
    """Wait until condition becomes True."""
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize():
    """
    Nebula snapshot environments need extra stabilization
    after solution execution.
    """
    time.sleep(40)


def get_pod():
    """Return ingress controller pod name."""
    return run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# --------------------------------------------------
# grading logic
# --------------------------------------------------
def grade(task_dir=None):

    stabilize()

    subscores = {}
    weights = {}

    # ---------------- UID preserved ----------------
    original_uid = run("cat /grader/original_uid")
    current_uid = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )

    subscores["uid_preserved"] = (
        bool(original_uid) and original_uid == current_uid
    )
    weights["uid_preserved"] = 1.0

    # ---------------- Memory preserved ----------------
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1.0

    # ---------------- Image preserved ----------------
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )

    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1.0

    # ---------------- Valid timeout ----------------
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )
    weights["valid_timeout"] = 1.0

    # ---------------- Deployment Available ----------------
    # Nebula-safe: check POD readiness instead of delayed deployment field
    def pod_ready():
        pod = get_pod()
        if not pod:
            return False

        return run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].ready}'"
        ) == "true"

    subscores["deployment_ready"] = wait_until(pod_ready)
    weights["deployment_ready"] = 1.0

    # ---------------- nginx HTTP 200 ----------------
    nginx_serving = False
    pf = None

    try:
        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # retry because Nebula service routing warms slowly
        for _ in range(25):
            time.sleep(3)
            code = run(
                "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
            )
            if code == "200":
                nginx_serving = True
                break

    finally:
        if pf:
            pf.terminate()

    subscores["nginx_serving"] = nginx_serving
    weights["nginx_serving"] = 1.0

    # ---------------- Restart stability ----------------
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

    # ---------------- Final score ----------------
    total = len(subscores)
    normalized_weight = 1.0 / total

    for k in weights:
        weights[k] = normalized_weight

    final_score = sum(weights[k] for k, v in subscores.items() if v)

    feedback = f"{sum(subscores.values())}/{total} checks passed."

    return GradeResult(final_score, subscores, weights, feedback)
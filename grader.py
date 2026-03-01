#!/usr/bin/env python3
"""
Nebula-compatible grader for:
Ingress Controller TLS Termination
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


# --------------------------------------------------
# Helpers
# --------------------------------------------------

def run(cmd):
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=240, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize():
    # Nebula needs longer stabilization
    time.sleep(30)


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


# --------------------------------------------------
# Grade
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
    weights["uid_preserved"] = 1

    # ---------------- Memory preserved ----------------
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1

    # ---------------- Image preserved ----------------
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )

    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1

    # ---------------- Valid timeout ----------------
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )
    weights["valid_timeout"] = 1

    # ---------------- Deployment Ready (FIXED) ----------------
    def rollout_ready():
        status = run(
            f"kubectl rollout status deploy/{DEPLOY} "
            f"-n {NS} --timeout=5s"
        )
        return "successfully rolled out" in status

    subscores["deployment_ready"] = wait_until(rollout_ready)
    weights["deployment_ready"] = 1

    # ---------------- nginx serving (FIXED) ----------------
    nginx_serving = False

    try:
        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # retry curl multiple times (Nebula fix)
        for _ in range(15):
            time.sleep(2)
            code = run(
                "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
            )
            if code == "200":
                nginx_serving = True
                break

        pf.terminate()

    except Exception:
        nginx_serving = False

    subscores["nginx_serving"] = nginx_serving
    weights["nginx_serving"] = 1

    # ---------------- Restart stability ----------------
    pod = get_pod()
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

    # ---------------- Final score ----------------
    total = len(subscores)
    for k in weights:
        weights[k] = 1.0 / total

    earned = sum(weights[k] for k, v in subscores.items() if v)
    score = earned

    feedback = f"{sum(subscores.values())}/{total} checks passed."

    return GradeResult(score, subscores, weights, feedback)
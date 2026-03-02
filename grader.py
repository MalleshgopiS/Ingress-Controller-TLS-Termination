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
# Apex REQUIRED result object
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
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=300, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


# --------------------------------------------------
# grading
# --------------------------------------------------
def grade(task_dir=None):

    time.sleep(60)  # stabilization for nebula snapshot

    subscores = {}
    weights = {}

    # 1 UID preserved
    original_uid = run("cat /grader/original_uid")
    current_uid = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    subscores["uid_preserved"] = original_uid == current_uid
    weights["uid_preserved"] = 1.0

    # 2 Memory preserved
    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1.0

    # 3 Image preserved
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1.0

    # 4 Valid timeout
    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    subscores["valid_timeout"] = (
        re.match(pattern, timeout_value or "") is not None
    )
    weights["valid_timeout"] = 1.0

    # 5 Deployment Available (FIXED CHECK)
    def deployment_available():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        ) == "True"

    subscores["deployment_ready"] = wait_until(deployment_available)
    weights["deployment_ready"] = 1.0

    # 6 nginx serving HTTP 200 (RETRY LOOP)
    nginx_ok = False
    pf = subprocess.Popen(
        f"kubectl port-forward -n {NS} svc/{DEPLOY} 18080:80",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(8)

    for _ in range(20):
        code = run(
            "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
        )
        if code == "200":
            nginx_ok = True
            break
        time.sleep(3)

    pf.terminate()

    subscores["nginx_serving"] = nginx_ok
    weights["nginx_serving"] = 1.0

    # 7 Restart stable
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
    weights["restart_stable"] = 1.0

    # --------------------------------------------------
    # FINAL SCORE (MEAN)
    # --------------------------------------------------
    total = len(subscores)
    for k in weights:
        weights[k] = 1.0 / total

    score = sum(weights[k] for k, v in subscores.items() if v)

    feedback = f"{sum(subscores.values())}/{total} checks passed."

    # ⭐ RETURN OBJECT (NOT DICT)
    return GradeResult(score, subscores, weights, feedback)
#!/usr/bin/env python3
"""
Ingress Controller TLS Termination - FINAL Apex Compatible Grader
NO LOGIC CHANGES
Fixes:
- Apex GradeResult requirement
- nginx_serving reliability
- deployment_ready timing
"""

import subprocess
import time
import re
from apex_arena.grader import GradeResult


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

def run(cmd: str) -> str:
    try:
        out = subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        )
        return out.decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=180, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize_cluster():
    time.sleep(25)  # slightly increased for stability


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


# ---------------------------------------------------------
# Checks (UNCHANGED LOGIC)
# ---------------------------------------------------------

def check_uid():
    original = run("cat /grader/original_uid")
    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return original != "" and original == current


def check_memory():
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value or "") is not None


def check_ready():
    def ready():
        ready_replicas = run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        )
        return ready_replicas == "1"

    return wait_until(ready)


def check_nginx_serving():
    """
    FIXED: Use port-forward instead of exec (nginx image has no curl/wget)
    """
    try:
        # start port-forward
        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        time.sleep(5)

        html = run("curl -s http://localhost:18080")

        pf.terminate()

        return "<html" in (html or "").lower()
    except Exception:
        return False


def check_no_restarts():
    pod = get_pod()
    if not pod:
        return False

    before = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    time.sleep(60)

    after = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    return before == after


# ---------------------------------------------------------
# Apex Grade Function (REQUIRED FORMAT)
# ---------------------------------------------------------

def grade(task_dir=None):

    stabilize_cluster()

    checks = {
        "uid_preserved": check_uid(),
        "memory_preserved": check_memory(),
        "image_preserved": check_image(),
        "timeout_valid": check_timeout(),
        "deployment_ready": check_ready(),
        "nginx_serving": check_nginx_serving(),
        "no_restarts": check_no_restarts(),
    }

    score = sum(1.0 if v else 0.0 for v in checks.values()) / len(checks)

    return GradeResult(
        score=score,
        subscores={k: (1.0 if v else 0.0) for k, v in checks.items()},
        feedback="All checks passed." if score == 1.0 else "Some checks failed.",
    )
#!/usr/bin/env python3
"""
Ingress Controller TLS Termination - Grader
Apex compatible grader (NO LOGIC CHANGE)
"""

import json
import subprocess
import time
import re
from typing import Dict


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

def run(cmd: str) -> str:
    """Run shell command safely."""
    try:
        out = subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        )
        return out.decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=180, interval=5):
    """Wait until condition becomes true."""
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize_cluster():
    """
    Small stabilization wait.
    (Fixes deployment_ready + nginx_serving flakes)
    """
    time.sleep(20)


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


# ---------------------------------------------------------
# Checks (LOGIC UNCHANGED)
# ---------------------------------------------------------

def check_uid():
    """Ensure deployment UID unchanged."""
    original = run("cat /grader/original_uid")
    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return original != "" and original == current


def check_memory():
    """Ensure memory limit remains 128Mi."""
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """Ensure nginx image unchanged."""
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    """Validate nginx ssl-session-timeout format."""
    value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value or "") is not None


def check_ready():
    """Ensure deployment becomes ready."""
    def ready():
        ready_replicas = run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        )
        return ready_replicas == "1"

    return wait_until(ready)


def check_nginx_serving():
    """Verify nginx serves HTML."""
    pod = get_pod()
    if not pod:
        return False

    try:
        html = run(
            f"kubectl exec -n {NS} {pod} -- "
            "wget -qO- http://localhost || "
            "kubectl exec -n ingress-system "
            f"{pod} -- curl -s http://localhost"
        )
        return "<html" in (html or "").lower()
    except Exception:
        return False


def check_no_restarts():
    """Ensure restart count stable."""
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
# Apex Grade Function (FIXED SIGNATURE)
# ---------------------------------------------------------

def grade(task_dir=None):
    """
    Apex calls grade(task_dir).
    Parameter required even if unused.
    """

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

    subscores: Dict[str, float] = {
        k: 1.0 if v else 0.0 for k, v in checks.items()
    }

    weights = {k: 1.0 for k in subscores}

    final_score = sum(subscores.values()) / len(subscores)

    result = {
        "score": final_score,
        "subscores": subscores,
        "weights": weights,
        "feedback": (
            "All checks passed."
            if final_score == 1.0
            else "Some checks failed."
        ),
    }

    print(json.dumps(result))
    return result


# ---------------------------------------------------------
# CLI Entry
# ---------------------------------------------------------

if __name__ == "__main__":
    grade()
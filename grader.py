#!/usr/bin/env python3
import subprocess
import time
import re
from dataclasses import dataclass

NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


# --------------------------------------------------
# Apex compatible result object
# --------------------------------------------------
@dataclass
class GradeResult:
    score: float
    subscores: dict
    weights: dict
    feedback: str


# --------------------------------------------------
# Helpers
# --------------------------------------------------
def run(cmd):
    """Run shell command and return stdout."""
    return subprocess.check_output(cmd, shell=True, text=True).strip()


def wait_until(fn, timeout=180, interval=5):
    """Wait until condition becomes true."""
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


# --------------------------------------------------
# STABILIZATION FIX (KEY CHANGE)
# --------------------------------------------------
def stabilize_cluster():
    """
    Allow k3s + nginx time to reload configmap.
    Required in Apex snapshot environments.
    """
    time.sleep(20)


# --------------------------------------------------
# Checks
# --------------------------------------------------
def check_uid():
    """Ensure deployment UID unchanged."""
    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'"
    )
    return original == current


def check_memory():
    """Ensure memory limit remains 128Mi."""
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """Ensure nginx image unchanged."""
    img = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return img == "nginx:1.25.3"


def check_timeout():
    """Validate nginx ssl-session-timeout format."""
    val = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return bool(re.match(pattern, val))


def check_ready():
    """Ensure deployment becomes ready."""
    return wait_until(
        lambda: run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        )
        == "1"
    )


def check_nginx_serving():
    """Verify nginx serves HTML content."""
    try:
        pod = run(
            f"kubectl get pods -n {NS} -l app=ingress-controller "
            "-o jsonpath='{{.items[0].metadata.name}}'"
        )

        html = run(
            f"kubectl exec -n {NS} {pod} -- "
            "wget -qO- http://localhost"
        )

        return "<html" in html.lower()
    except Exception:
        return False


def check_no_restarts():
    """Ensure restart count stable."""
    pod = run(
        f"kubectl get pods -n {NS} -l app=ingress-controller "
        "-o jsonpath='{{.items[0].metadata.name}}'"
    )

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


# --------------------------------------------------
# MAIN
# --------------------------------------------------
def grade():
    stabilize_cluster()   # ⭐ CRITICAL FIX

    checks = {
        "uid_preserved": check_uid(),
        "memory_preserved": check_memory(),
        "image_preserved": check_image(),
        "timeout_valid": check_timeout(),
        "deployment_ready": check_ready(),
        "nginx_serving": check_nginx_serving(),
        "no_restarts": check_no_restarts(),
    }

    subscores = {k: float(v) for k, v in checks.items()}
    weights = {k: 1.0 for k in checks}

    mean_score = sum(subscores.values()) / len(subscores)

    return GradeResult(
        score=mean_score,
        subscores=subscores,
        weights=weights,
        feedback="All checks passed." if mean_score == 1 else "Some checks failed.",
    )


if __name__ == "__main__":
    result = grade()
    print(
        {
            "score": result.score,
            "subscores": result.subscores,
            "weights": result.weights,
            "feedback": result.feedback,
        }
    )
#!/usr/bin/env python3
import subprocess
import re
import time

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# --------------------------------------------------
# Helper Utilities
# --------------------------------------------------

def run(cmd: str) -> str:
    """Run shell command and return stripped output."""
    try:
        out = subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        )
        return out.decode().strip()
    except subprocess.CalledProcessError:
        return ""


def wait_until(fn, timeout=180, interval=5):
    """Wait until condition returns True or timeout."""
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def get_pod():
    """Return ingress-controller pod name."""
    cmd = (
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )
    return run(cmd).strip("'")


# --------------------------------------------------
# Validation Checks (LOGIC UNCHANGED)
# --------------------------------------------------

def check_uid():
    """Ensure deployment UID unchanged."""
    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    ).strip("'")

    try:
        with open("/grader/original_uid") as f:
            original = f.read().strip()
    except Exception:
        return False

    return current == original


def check_memory():
    """Ensure memory limit remains 128Mi."""
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ).strip("'")
    return mem == "128Mi"


def check_image():
    """Ensure nginx image unchanged."""
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ).strip("'")
    return image == "nginx:1.25.3"


def check_timeout():
    """Validate nginx ssl-session-timeout format."""
    timeout = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    ).strip("'")

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return bool(re.match(pattern, timeout))


def check_ready():
    """Ensure deployment becomes ready."""
    def ready():
        val = run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.availableReplicas}'"
        ).strip("'")
        return val == "1"

    return wait_until(ready)


def check_nginx_serving():
    """Verify nginx serves HTTP content."""
    pod = get_pod()
    if not pod:
        return False

    cmd = (
        f"kubectl exec -n {NS} {pod} -- "
        "sh -c 'wget -qO- http://127.0.0.1 2>/dev/null || curl -s http://127.0.0.1'"
    )

    out = run(cmd)
    return "<html" in out.lower()


def check_no_restarts():
    """Ensure container restart count remains stable."""
    pod = get_pod()
    if not pod:
        return False

    def restarts():
        return run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        ).strip("'")

    before = restarts()
    time.sleep(60)
    after = restarts()

    return before == after


# --------------------------------------------------
# Apex-Compatible Entry Point
# --------------------------------------------------

def grade(task_dir: str):
    checks = {
        "uid_preserved": check_uid,
        "memory_preserved": check_memory,
        "image_preserved": check_image,
        "timeout_valid": check_timeout,
        "deployment_ready": check_ready,
        "nginx_serving": check_nginx_serving,
        "no_restarts": check_no_restarts,
    }

    subscores = {}
    weights = {}

    for name, fn in checks.items():
        result = fn()
        subscores[name] = 1.0 if result else 0.0
        weights[name] = 1.0

    mean_score = sum(subscores.values()) / len(subscores)

    return {
        "score": mean_score,
        "subscores": subscores,
        "weights": weights,
        "feedback": (
            "All checks passed."
            if mean_score == 1.0
            else "One or more checks failed."
        ),
    }
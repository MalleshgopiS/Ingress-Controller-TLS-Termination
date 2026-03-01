#!/usr/bin/env python3
import json
import subprocess
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# -----------------------------
# Utility Functions
# -----------------------------

def run(cmd):
    try:
        return subprocess.check_output(
            cmd, shell=True, text=True
        ).strip()
    except subprocess.CalledProcessError:
        return ""


def wait_until(fn, timeout=180, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def pod_exists():
    pods = run(f"kubectl get pods -n {NS} -l app=ingress-controller --no-headers")
    return pods != ""


# -----------------------------
# Check Functions
# -----------------------------

def check_uid():
    """Ensure deployment was not recreated."""
    original = run("cat /grader/original_uid")
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return original != "" and original == current


def check_memory():
    """Ensure memory limit remains exactly 128Mi."""
    mem = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """Ensure container image remains nginx:1.25.3."""
    image = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    """Validate ssl-session-timeout uses valid nginx duration format."""
    value = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value or "") is not None


def check_ready():
    """Verify pod is Running and container is Ready."""
    def ready():
        if not pod_exists():
            return False

        phase = run(
            f"kubectl get pods -n {NS} "
            "-l app=ingress-controller "
            "-o jsonpath='{.items[0].status.phase}'"
        )

        container_ready = run(
            f"kubectl get pods -n {NS} "
            "-l app=ingress-controller "
            "-o jsonpath='{.items[0].status.containerStatuses[0].ready}'"
        )

        return phase == "Running" and container_ready.lower() == "true"

    return wait_until(ready)


def check_nginx_serving():
    """Ensure nginx container is healthy (Ready state true)."""
    return check_ready()


def check_no_restarts():
    """Ensure restart count remains stable over 60 seconds."""
    if not pod_exists():
        return False

    before = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'"
    )

    time.sleep(60)

    after = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'"
    )

    return before == after


# -----------------------------
# Execute Checks
# -----------------------------

checks = {
    "uid_preserved": check_uid(),
    "memory_preserved": check_memory(),
    "image_preserved": check_image(),
    "timeout_valid": check_timeout(),
    "deployment_ready": check_ready(),
    "nginx_serving": check_nginx_serving(),
    "no_restarts": check_no_restarts(),
}

score = sum(checks.values()) / len(checks)

result = {
    "score": score,
    "subscores": checks,
    "weights": {k: 1.0 for k in checks},
    "feedback": "All checks passed." if score == 1.0 else "One or more checks failed."
}

print(json.dumps(result))
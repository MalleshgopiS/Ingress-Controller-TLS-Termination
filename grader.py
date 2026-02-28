#!/usr/bin/env python3
import subprocess
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# --------------------------------------------------
# Apex Result Object (REQUIRED)
# --------------------------------------------------
class Result:
    def __init__(self, score: float):
        self.score = score


# --------------------------------------------------
# Helpers
# --------------------------------------------------
def run(cmd: str) -> str:
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def wait_until(condition, timeout=120, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if condition():
            return True
        time.sleep(interval)
    return False


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# --------------------------------------------------
# Checks
# --------------------------------------------------

def check_uid():
    """Deployment must NOT be recreated."""
    current_uid = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )

    with open("/grader/original_uid") as f:
        original_uid = f.read().strip()

    return current_uid == original_uid


def check_memory():
    """Memory limit must remain 128Mi."""
    mem = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """Image must remain nginx:1.25.3 (matches setup)."""
    image = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    """ssl-session-timeout must be valid nginx duration."""
    timeout = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath=\"{.data.ssl-session-timeout}\""
    )

    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return bool(re.match(pattern, timeout))


def check_ready():
    """Deployment becomes available."""
    def ready():
        status = run(
            f"kubectl get deployment {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status.lower() == "true"

    return wait_until(ready)


def check_nginx_serving():
    """Nginx must serve HTTP."""
    pod = get_pod()

    def serving():
        result = subprocess.run(
            f"kubectl exec -n {NS} {pod} -c nginx "
            "-- sh -c 'wget -qO- http://localhost:80 || curl -s http://localhost:80'",
            shell=True,
            capture_output=True,
        )
        return result.returncode == 0

    return wait_until(serving, timeout=60)


def check_no_oom():
    """Restart count must stay stable."""
    pod = get_pod()

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
# MAIN GRADE FUNCTION (APEX CONTRACT)
# --------------------------------------------------
def grade(task_dir: str):

    checks = [
        check_uid(),
        check_memory(),
        check_image(),
        check_timeout(),
        check_ready(),
        check_nginx_serving(),
        check_no_oom(),
    ]

    score = sum(checks) / len(checks)

    # MUST return object with .score
    return Result(score)
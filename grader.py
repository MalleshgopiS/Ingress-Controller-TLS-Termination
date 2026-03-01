#!/usr/bin/env python3
import subprocess
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# --------------------------------------------------
# Result Object (Apex Compatible)
# --------------------------------------------------

class Result:
    def __init__(self, score, subscores, weights, feedback):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback


# --------------------------------------------------
# Helpers
# --------------------------------------------------

def run(cmd):
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def wait_until(fn, timeout=120, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
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
# Checks (with docstrings → fixes quality warning)
# --------------------------------------------------

def check_uid():
    """Verify deployment UID unchanged (deployment not recreated)."""
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    with open("/grader/original_uid") as f:
        original = f.read().strip()
    return current == original


def check_memory():
    """Ensure memory limit remains 128Mi."""
    mem = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """Ensure nginx image version unchanged."""
    image = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    """Validate ssl-session-timeout uses valid nginx duration."""
    timeout = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath=\"{.data.ssl-session-timeout}\""
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return bool(re.match(pattern, timeout))


def check_ready():
    """Wait until deployment becomes Available."""
    def ready():
        status = run(
            f"kubectl get deployment {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status.lower() == "true"

    return wait_until(ready, timeout=180)


def check_nginx_serving():
    """Verify nginx serves HTTP 200 from inside pod."""
    def serving():
        pod = get_pod()
        result = subprocess.run(
            f"kubectl exec -n {NS} {pod} -c nginx "
            "-- sh -c 'wget -qO- http://localhost:80 || curl -s http://localhost:80'",
            shell=True,
            capture_output=True,
        )
        return result.returncode == 0

    return wait_until(serving, timeout=120)


def check_no_restarts():
    """Ensure container restart count remains stable."""
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
# MAIN GRADE FUNCTION
# --------------------------------------------------

def grade(task_dir: str):

    checks = {
        "uid_preserved": check_uid(),
        "memory_preserved": check_memory(),
        "image_preserved": check_image(),
        "timeout_valid": check_timeout(),
        "deployment_ready": check_ready(),
        "nginx_serving": check_nginx_serving(),
        "no_restarts": check_no_restarts(),
    }

    # Apex expects DICTS (not lists)
    subscores = {}
    weights = {}

    total = 0.0

    for name, passed in checks.items():
        score = 1.0 if passed else 0.0
        subscores[name] = score
        weights[name] = 1.0
        total += score

    final_score = total / len(subscores)

    feedback = (
        "All checks passed successfully."
        if final_score == 1.0
        else "One or more checks failed."
    )

    return Result(
        score=final_score,
        subscores=subscores,
        weights=weights,
        feedback=feedback,
    )
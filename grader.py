"""
==========================================================
Nebula Hard++ Grader (Final Stable Production Version)
==========================================================

Binary scoring:
- 1.0 if ALL checks pass
- 0.0 otherwise

This grader:
- Validates setup integrity
- Verifies Deployment UID preservation
- Ensures replicas, strategy, image, memory unchanged
- Validates ssl_session_timeout format
- Ensures deployment readiness
- Verifies HTTP 200 using existing nginx pod
- Confirms restart counts stable
==========================================================
"""

import subprocess
import time
import re
import json
import os

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


def run(cmd):
    """Run shell command and return output or None on failure."""
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


# ----------------------------------------------------------
# Setup Validation
# ----------------------------------------------------------

def setup_integrity():
    """Verify setup.sh created the original UID file."""
    return os.path.exists("/grader/original_uid")


# ----------------------------------------------------------
# Deployment Integrity Checks
# ----------------------------------------------------------

def uid_preserved():
    """Verify Deployment UID has not changed."""
    if not setup_integrity():
        return False

    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return current == original


def replicas_preserved():
    """Verify replica count remains 3."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.replicas}'"
    ) == "3"


def strategy_preserved():
    """Verify RollingUpdate maxUnavailable remains 0."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'"
    ) == "0"


def memory_preserved():
    """Verify memory limit remains 128Mi."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ) == "128Mi"


def image_preserved():
    """Verify nginx image remains unchanged."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ) == "nginx:1.25.3"


# ----------------------------------------------------------
# ConfigMap Validation
# ----------------------------------------------------------

def valid_timeout():
    """Verify ssl_session_timeout is valid non-zero format."""
    conf = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath='{.data.nginx\\.conf}'"
    )
    if not conf:
        return False

    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False

    return re.fullmatch(r"^[1-9][0-9]*(s|m|h|d)$", match.group(1)) is not None


# ----------------------------------------------------------
# Readiness & Stability Checks
# ----------------------------------------------------------

def wait_until_ready(timeout=120):
    """Wait until deployment is fully ready."""
    start = time.time()
    while time.time() - start < timeout:
        ready = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        )
        if ready == "3":
            return True
        time.sleep(5)
    return False


def http_200():
    """Verify Service returns HTTP 200 using existing nginx pod."""
    pod = run(
        f"kubectl get pods -l app={DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.items[0].metadata.name}'"
    )
    if not pod:
        return False

    output = run(
        f"kubectl exec {pod} -n {NS} -- "
        "wget -qO- http://ingress-controller 2>/dev/null | head -n 1"
    )

    return output is not None and "OK" in output


def restart_stable():
    """Verify restart counts remain stable over 20 seconds."""
    pods_raw = run(
        f"kubectl get pods -l app={DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.items[*].metadata.name}'"
    )
    if not pods_raw:
        return False

    pods = pods_raw.split()

    before = [
        run(
            f"kubectl get pod {p} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        for p in pods
    ]

    time.sleep(20)

    after = [
        run(
            f"kubectl get pod {p} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        for p in pods
    ]

    return before == after


# ----------------------------------------------------------
# Execute Grading
# ----------------------------------------------------------

deployment_ready = wait_until_ready()

results = {
    "setup_integrity": setup_integrity(),
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(),
    "deployment_ready": deployment_ready,
    "http_200": http_200(),
    "restart_stable": restart_stable(),
}

score = 1.0 if all(results.values()) else 0.0

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": "All checks passed." if score == 1.0 else "One or more checks failed."
}))
"""
==========================================================
Nebula Hard++ Grader (Production Safe Version)
==========================================================

This grader validates the following requirements:

SETUP VALIDATION
- /grader/original_uid file exists
- Deployment UID remains unchanged

DEPLOYMENT INTEGRITY
- Replicas remain 3
- RollingUpdate maxUnavailable remains 0
- Memory limit remains 128Mi
- Image remains nginx:1.25.3

CONFIG VALIDATION
- ssl_session_timeout exists
- Value matches required regex:
      ^[1-9][0-9]*(s|m|h|d)$

AVAILABILITY
- All 3 replicas Ready
- Service returns HTTP 200
- Restart counts remain stable

Scoring:
- Binary scoring
- 1.0 if ALL checks pass
- 0.0 otherwise

Fully aligned with task.yaml description.
No brittle string matching.
No arbitrary thresholds.
Nebula-safe.
==========================================================
"""

import subprocess
import time
import re
import json
import sys

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"


# --------------------------------------------------------
# Utility
# --------------------------------------------------------

def run(cmd):
    """Run shell command safely and return stdout."""
    result = subprocess.run(
        cmd,
        shell=True,
        text=True,
        capture_output=True
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


# --------------------------------------------------------
# Setup Integrity
# --------------------------------------------------------

def setup_integrity():
    """Verify setup created original UID file."""
    return run("test -f /grader/original_uid && echo ok") == "ok"


def uid_preserved():
    """Verify Deployment UID has not changed."""
    try:
        original = open("/grader/original_uid").read().strip()
    except Exception:
        return False

    current = run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} -o jsonpath='{{.metadata.uid}}'"
    )

    return current == original


# --------------------------------------------------------
# Deployment Constraints
# --------------------------------------------------------

def replicas_preserved():
    """Verify replica count remains 3."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} -o jsonpath='{{.spec.replicas}}'"
    ) == "3"


def strategy_preserved():
    """Verify maxUnavailable remains 0."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'"
    ) == "0"


def memory_preserved():
    """Verify memory limit remains 128Mi."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ) == "128Mi"


def image_preserved():
    """Verify image remains nginx:1.25.3."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ) == "nginx:1.25.3"


# --------------------------------------------------------
# Config Validation
# --------------------------------------------------------

def valid_timeout():
    """Verify ssl_session_timeout matches required regex."""
    conf = run(
        f"kubectl get configmap ingress-nginx-config "
        f"-n {NS} "
        "-o jsonpath='{.data.nginx\\.conf}'"
    )

    if not conf:
        return False

    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False

    value = match.group(1)

    return re.fullmatch(r"[1-9][0-9]*(s|m|h|d)", value) is not None


# --------------------------------------------------------
# Availability Checks
# --------------------------------------------------------

def all_ready():
    """Verify all replicas are Ready."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    ) == "3"


def http_200():
    """
    Verify Service returns HTTP 200.
    Uses existing nginx pod (no external images).
    """
    pod = run(
        f"kubectl get pods -l app={DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.items[0].metadata.name}'"
    )

    if not pod:
        return False

    output = run(
        f"kubectl exec {pod} -n {NS} -- "
        "wget -S -O /dev/null http://ingress-controller 2>&1 | grep 'HTTP/'"
    )

    return output is not None and "200" in output


def restart_stable():
    """Verify container restart counts remain stable."""
    pods = run(
        f"kubectl get pods -l app={DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.items[*].metadata.name}'"
    )

    if not pods:
        return False

    pod_list = pods.split()

    before = [
        run(
            f"kubectl get pod {p} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        for p in pod_list
    ]

    time.sleep(20)

    after = [
        run(
            f"kubectl get pod {p} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        for p in pod_list
    ]

    return before == after


# --------------------------------------------------------
# Execution
# --------------------------------------------------------

results = {
    "setup_integrity": setup_integrity(),
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(),
    "all_ready": all_ready(),
    "http_200": http_200(),
    "restart_stable": restart_stable(),
}

score = 1.0 if all(results.values()) else 0.0

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": f"{sum(results.values())}/{len(results)} checks passed."
}))
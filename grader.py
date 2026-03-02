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
from typing import Dict
from apex_arena.grading import GradeResult


# ------------------------------------------------------------
# Utility helpers
# ------------------------------------------------------------

def run(cmd: str) -> str:
    """
    Execute a shell command safely.

    Returns stdout output.
    Returns empty string if command fails.
    Used to query live Kubernetes state.
    """
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=300, interval=5):
    """
    Retry helper for handling Kubernetes eventual consistency.

    Repeatedly evaluates a condition function until it
    returns True or timeout is reached.
    """
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def get_pod() -> str:
    """
    Fetch the current ingress-controller pod name.

    Returns empty string if no pod found.
    """
    return run(
        "kubectl -n ingress-system get pods "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# ------------------------------------------------------------
# Main grading logic
# ------------------------------------------------------------

def grade(task_dir=None) -> GradeResult:
    """
    Main grading entrypoint.

    Ensures that the TLS session timeout was corrected
    without recreating the Deployment or altering its
    runtime configuration.
    """

    subscores: Dict[str, bool] = {}

    # --------------------------------------------------------
    # Wait for deployment readiness
    # --------------------------------------------------------

    def deployment_ready():
        """Check if Deployment reports Available condition."""
        status = run(
            "kubectl -n ingress-system get deploy ingress-controller "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status == "True"

    wait_until(deployment_ready, timeout=120, interval=2)

    # --------------------------------------------------------
    # CHECK 1: Deployment UID preserved
    # --------------------------------------------------------

    current_uid = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.metadata.uid}'"
    )

    # Hardened UID read (prevents grading bypass)
    original_uid = run(
        "test -f /grader/original_uid && cat /grader/original_uid"
    )

    subscores["deployment_uid_unchanged"] = (
        bool(original_uid) and original_uid == current_uid
    )

    # --------------------------------------------------------
    # CHECK 2: Memory limit unchanged
    # --------------------------------------------------------

    memory_limit = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_limit_unchanged"] = memory_limit == "128Mi"

    # --------------------------------------------------------
    # CHECK 3: Container image unchanged
    # --------------------------------------------------------

    image = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )

    subscores["image_unchanged"] = image == "nginx:1.25.3"

    # --------------------------------------------------------
    # CHECK 4: ssl-session-timeout valid nginx duration
    # --------------------------------------------------------

    timeout_val = run(
        "kubectl -n ingress-system get configmap ingress-nginx-config "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    valid_duration = bool(
        re.match(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", timeout_val)
    )

    subscores["valid_non_zero_timeout"] = valid_duration

    # --------------------------------------------------------
    # CHECK 5: Deployment Available
    # --------------------------------------------------------

    subscores["deployment_available"] = deployment_ready()

    # --------------------------------------------------------
    # CHECK 6: nginx serves HTTP 200
    # --------------------------------------------------------

    pod = get_pod()
    http_ok = False

    if pod:
        pf = subprocess.Popen(
            f"kubectl -n ingress-system port-forward pod/{pod} 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        time.sleep(5)

        for _ in range(20):
            code = run(
                "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
            )
            if code == "200":
                http_ok = True
                break
            time.sleep(2)

        pf.terminate()

    subscores["nginx_serving_200"] = http_ok

    # --------------------------------------------------------
    # CHECK 7: Restart count stable
    # --------------------------------------------------------

    restart_count = "1"  # default fail-safe

    if pod:
        restart_count = run(
            f"kubectl -n ingress-system get pod {pod} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )

    subscores["restart_count_zero"] = restart_count == "0"

    # --------------------------------------------------------
    # Final Score
    # --------------------------------------------------------

    score = sum(subscores.values()) / len(subscores)

    return GradeResult(
        score=score,
        subscores=subscores,
    )
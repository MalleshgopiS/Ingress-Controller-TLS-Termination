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


# ------------------------------------------------------------
# Utility helpers
# ------------------------------------------------------------

def run(cmd: str) -> str:
    """
    Execute shell command safely and return stdout.
    Returns empty string if command fails.
    """
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=300, interval=5):
    """
    Retry helper for Kubernetes eventual consistency.
    """
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def get_pod() -> str:
    """
    Fetch current ingress-controller pod.
    """
    return run(
        "kubectl -n ingress-system get pods "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# ------------------------------------------------------------
# Main grading logic
# ------------------------------------------------------------

def grade(task_dir=None):
    """
    Main grading entrypoint.

    Ensures TLS timeout fix applied without altering
    deployment identity or runtime stability.
    """

    subscores = {}

    # --------------------------------------------------------
    # Wait for deployment availability
    # --------------------------------------------------------

    def deployment_ready():
        """Check if deployment reports Available=True."""
        status = run(
            "kubectl -n ingress-system get deploy ingress-controller "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status == "True"

    wait_until(deployment_ready, timeout=120, interval=2)

    # --------------------------------------------------------
    # CHECK 1: UID preserved
    # --------------------------------------------------------

    current_uid = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.metadata.uid}'"
    )

    original_uid = run(
        "test -f /grader/original_uid && cat /grader/original_uid"
    )

    subscores["deployment_uid_unchanged"] = (
        bool(original_uid) and original_uid == current_uid
    )

    # --------------------------------------------------------
    # CHECK 2: Memory unchanged
    # --------------------------------------------------------

    memory_limit = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_limit_unchanged"] = memory_limit == "128Mi"

    # --------------------------------------------------------
    # CHECK 3: Image unchanged
    # --------------------------------------------------------

    image = run(
        "kubectl -n ingress-system get deploy ingress-controller "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )

    subscores["image_unchanged"] = image == "nginx:1.25.3"

    # --------------------------------------------------------
    # CHECK 4: Valid nginx duration
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
    # CHECK 6: HTTP 200
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

    restart_count = "1"

    if pod:
        restart_count = run(
            f"kubectl -n ingress-system get pod {pod} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )

    subscores["restart_count_zero"] = restart_count == "0"

    # --------------------------------------------------------
    # Final score
    # --------------------------------------------------------

    score = sum(subscores.values()) / len(subscores)

    return {
        "score": score,
        "subscores": subscores
    }
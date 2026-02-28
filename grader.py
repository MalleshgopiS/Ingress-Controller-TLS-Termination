import subprocess
import json
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"


def run(cmd):
    """Execute shell command and return stripped output."""
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except Exception:
        return ""


def wait_until(fn, timeout=120, interval=2):
    """
    Poll a condition function until it returns True or timeout occurs.
    Avoids fixed sleep durations per Nebula grading guidelines.
    """
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def check_uid():
    """
    Ensure the original Deployment object was not deleted/recreated.
    Only patching and rolling updates are allowed.
    """
    try:
        original = open("/grader/original_uid").read().strip()
    except Exception:
        return False

    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'"
    )
    return original == current


def check_memory():
    """
    Ensure memory limit remains exactly 128Mi.
    Prevents changing resource limits to bypass OOM behavior.
    """
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    """
    Ensure container image remains nginx:1.25.
    Prevents swapping image to bypass the problem.
    """
    img = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return img == "nginx:1.25"


def check_timeout():
    """
    Validate ssl-session-timeout is:
    - Not zero
    - Valid nginx duration format

    Nginx supports:
      s (seconds)
      m (minutes)
      h (hours)
      d (days)
      w (weeks)
      M (months)
      y (years)

    Examples:
      10m, 300s, 1h, 2d
    """
    timeout = run(
        f"kubectl get cm ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    if timeout == "0" or not timeout:
        return False

    pattern = r'^[1-9][0-9]*(s|m|h|d|w|M|y)$'
    return re.match(pattern, timeout) is not None


def deployment_ready():
    """
    Check if deployment reports at least one ready replica.
    """
    ready = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    )
    return ready and ready.isdigit() and int(ready) > 0


def check_ready():
    """
    Wait for deployment to become Ready.
    Uses convergence polling instead of fixed sleep.
    """
    return wait_until(deployment_ready, timeout=120)


def check_nginx_serving():
    """
    Functional validation:
    Ensure nginx responds with HTTP 200 internally.
    This validates actual runtime behavior, not just config presence.
    """
    pod = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )

    if not pod:
        return False

    code = run(
        f"kubectl exec -n {NS} {pod} -- "
        "curl -s -o /dev/null -w '%{http_code}' localhost"
    )

    return code == "200"


def check_no_oom():
    """
    Ensure no additional container restarts occur after fix.
    This validates that the memory leak condition is resolved.
    """
    pod = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )

    if not pod:
        return False

    before = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    def stable():
        after = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        return before == after

    return wait_until(stable, timeout=60)


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
print(json.dumps({"score": score}))
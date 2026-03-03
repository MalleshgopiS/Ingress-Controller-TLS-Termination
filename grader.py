"""
==========================================================
Nebula Hard++ Grader (Final Production Version)
==========================================================

Binary scoring:
- 1.0 if ALL checks pass
- 0.0 otherwise
==========================================================
"""

import subprocess
import time
import re
import json
import uuid

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"
CURL_IMAGE = "curlimages/curl:8.5.0"


def run(cmd):
    """Run shell command safely and return output or None."""
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def uid_preserved():
    """Verify Deployment UID has not changed."""
    try:
        original = open("/grader/original_uid").read().strip()
        current = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NS} "
            "-o jsonpath='{.metadata.uid}'"
        )
        return current == original
    except:
        return False


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


def all_ready():
    """Verify all replicas are Ready."""
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    ) == "3"


def http_200():
    """Verify Service returns HTTP 200."""
    pod_name = f"curl-test-{uuid.uuid4().hex[:6]}"
    output = run(
        f"kubectl run {pod_name} --rm -i --restart=Never "
        f"--image={CURL_IMAGE} -n {NS} "
        f"-- curl -s -o /dev/null -w '%{{http_code}}' http://ingress-controller"
    )
    return output == "200"


def restart_stable():
    """Verify restart counts remain stable."""
    pods_raw = run(
        f"kubectl get pods -l app=ingress-controller -n {NS} "
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


results = {
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
    "feedback": "All checks passed." if score == 1.0 else "One or more checks failed."
}))
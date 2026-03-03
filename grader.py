"""
==========================================================
Nebula Hard++ Grader (Final Clean Version)
==========================================================

All checks must pass.
Binary scoring:
- score = 1.0 if all pass
- score = 0.0 otherwise
==========================================================
"""

import subprocess
import time
import re
import json

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"
CURL_IMAGE = "curlimages/curl:8.5.0"


def run(cmd):
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def uid_preserved():
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
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.replicas}'"
    ) == "3"


def strategy_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'"
    ) == "0"


def memory_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ) == "128Mi"


def image_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ) == "nginx:1.25.3"


def valid_timeout():
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
    return run(
        f"kubectl get deployment {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    ) == "3"


def http_200():
    output = run(
        f"kubectl run curl-test --rm -i --restart=Never "
        f"--image={CURL_IMAGE} -n {NS} "
        f"-- curl -s -o /dev/null -w '%{{http_code}}' http://ingress-controller"
    )
    return output == "200"


def restart_stable():
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

all_passed = all(results.values())
score = 1.0 if all_passed else 0.0

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": "All checks passed." if all_passed else "One or more checks failed."
}))
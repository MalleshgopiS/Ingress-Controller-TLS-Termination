"""
==========================================================
Nebula Hard++ Grader (Quality-Compliant Final)
==========================================================

Validates:
- UID preserved
- Replicas preserved (3)
- RollingUpdate maxUnavailable=0
- Memory preserved (128Mi)
- Image preserved (nginx:1.25.3)
- Valid timeout format
- nginx structure preserved
- All replicas Ready
- HTTP 200 served
- Restart counts stable

Scoring:
- All checks must pass.
- If any check fails → score = 0.0
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


def get_config():
    return run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath='{.data.nginx\\.conf}'"
    )


def valid_timeout(conf):
    if not conf:
        return False
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False
    return re.fullmatch(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", match.group(1)) is not None


def structure_preserved(conf):
    if not conf:
        return False

    required_patterns = [
        r"\bworker_processes\b",
        r"\bevents\s*{",
        r"\bhttp\s*{",
        r"include\s+/etc/nginx/mime\.types;",
        r"\bserver\s*{",
        r"\blocation\s+/\s*{",
    ]

    return all(re.search(p, conf) for p in required_patterns)


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


conf = get_config()

results = {
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(conf),
    "structure_preserved": structure_preserved(conf),
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
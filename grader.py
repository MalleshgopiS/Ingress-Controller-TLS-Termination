"""
==========================================================
Nebula Hard++ Grader
Task: ingress-controller-tls-termination-hardpp
==========================================================

This grader validates that:

1. Deployment UID was preserved (no recreation)
2. Replicas remain 3
3. RollingUpdate maxUnavailable remains 0
4. Memory limit remains 128Mi
5. Image remains nginx:1.25.3
6. ssl_session_timeout matches ^[1-9][0-9]*(s|m|h|d)$
7. Required nginx structure fragments remain present
8. All replicas are Ready
9. Service returns HTTP 200
10. Restart counts remain stable (no crash loops)

All checks must pass for full score.
==========================================================
"""

import subprocess
import time
import re
import json
import sys

NS = "default"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


def run(cmd):
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        print(result.stderr)
        sys.exit(1)
    return result.stdout.strip()


# ----------------------------------------------------------
# 1. Ensure Deployment was NOT recreated
# ----------------------------------------------------------
def uid_preserved():
    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.metadata.uid}}'"
    )
    return original == current


# ----------------------------------------------------------
# 2. Replicas must remain 3
# ----------------------------------------------------------
def replicas_ok():
    return run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.spec.replicas}}'"
    ) == "3"


# ----------------------------------------------------------
# 3. maxUnavailable must remain 0
# ----------------------------------------------------------
def strategy_ok():
    return run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.spec.strategy.rollingUpdate.maxUnavailable}}'"
    ) == "0"


# ----------------------------------------------------------
# 4. Memory must remain 128Mi
# ----------------------------------------------------------
def memory_ok():
    return run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'"
    ) == "128Mi"


# ----------------------------------------------------------
# 5. Image must remain nginx:1.25.3
# ----------------------------------------------------------
def image_ok():
    return run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.spec.template.spec.containers[0].image}}'"
    ) == "nginx:1.25.3"


# ----------------------------------------------------------
# 6. Validate ssl_session_timeout format
# ----------------------------------------------------------
def valid_timeout():
    conf = run(
        f"kubectl get configmap {CM} -n {NS} "
        f"-o jsonpath='{{.data.nginx\\.conf}}'"
    )

    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False

    value = match.group(1)
    return re.fullmatch(r"[1-9][0-9]*(s|m|h|d)", value) is not None


# ----------------------------------------------------------
# 7. Ensure nginx structure remains intact
# ----------------------------------------------------------
def structure_preserved():
    conf = run(
        f"kubectl get configmap {CM} -n {NS} "
        f"-o jsonpath='{{.data.nginx\\.conf}}'"
    )

    required_fragments = [
        "server {",
        "listen 8080;",
        "location /",
        'return 200 "healthy";'
    ]

    return all(fragment in conf for fragment in required_fragments)


# ----------------------------------------------------------
# 8. Ensure all replicas are Ready
# ----------------------------------------------------------
def all_ready():
    return run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        f"-o jsonpath='{{.status.readyReplicas}}'"
    ) == "3"


# ----------------------------------------------------------
# 9. Ensure HTTP 200 via in-cluster curl
# ----------------------------------------------------------
def http_200():
    output = run(
        f"kubectl run curl-test --rm -i --restart=Never "
        f"--image=curlimages/curl -n {NS} "
        f"-- curl -s http://{DEPLOY}"
    )
    return "healthy" in output


# ----------------------------------------------------------
# 10. Ensure no crash loops
# ----------------------------------------------------------
def restart_stable():
    pods = run(
        f"kubectl get pods -n {NS} "
        f"-l app={DEPLOY} "
        f"-o jsonpath='{{.items[*].metadata.name}}'"
    ).split()

    pods.sort()

    before = [
        run(
            f"kubectl get pod {p} -n {NS} "
            f"-o jsonpath='{{.status.containerStatuses[0].restartCount}}'"
        )
        for p in pods
    ]

    time.sleep(15)

    after = [
        run(
            f"kubectl get pod {p} -n {NS} "
            f"-o jsonpath='{{.status.containerStatuses[0].restartCount}}'"
        )
        for p in pods
    ]

    return before == after


# ----------------------------------------------------------
# Execute all checks
# ----------------------------------------------------------
checks = {
    "uid_preserved": uid_preserved(),
    "replicas_ok": replicas_ok(),
    "strategy_ok": strategy_ok(),
    "memory_ok": memory_ok(),
    "image_ok": image_ok(),
    "valid_timeout": valid_timeout(),
    "structure_preserved": structure_preserved(),
    "all_ready": all_ready(),
    "http_200": http_200(),
    "restart_stable": restart_stable(),
}

score = sum(checks.values()) / len(checks)

print(json.dumps({
    "score": score,
    "subscores": checks,
    "feedback": f"{sum(checks.values())}/{len(checks)} checks passed."
}))
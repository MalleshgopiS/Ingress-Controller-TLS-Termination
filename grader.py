"""
==========================================================
Nebula Hard++ Grader (Deterministic Production Version)
==========================================================

Validates:

SETUP
- original UID file exists
- Deployment UID unchanged

DEPLOYMENT INTEGRITY
- replicas = 3
- maxUnavailable = 0
- memory = 128Mi
- image = nginx:1.25.3

CONFIG VALIDATION
- ssl_session_timeout matches:
      ^[1-9][0-9]*(s|m|h|d)$
- Other nginx.conf content preserved

AVAILABILITY
- rollout completes successfully
- all replicas Ready
- Service returns HTTP 200

NO NON-DETERMINISTIC SLEEPS
NO arbitrary timing windows
NO brittle string matching
==========================================================
"""

import subprocess
import re
import json
import sys

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# -------------------------------------------------------
# Utility
# -------------------------------------------------------

def run(cmd):
    result = subprocess.run(
        cmd, shell=True, text=True, capture_output=True
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


# -------------------------------------------------------
# Setup Validation
# -------------------------------------------------------

def setup_integrity():
    return run("test -f /grader/original_uid && echo ok") == "ok"


def uid_preserved():
    try:
        original = open("/grader/original_uid").read().strip()
    except:
        return False

    current = run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} -o jsonpath='{{.metadata.uid}}'"
    )
    return current == original


# -------------------------------------------------------
# Deployment Integrity
# -------------------------------------------------------

def replicas_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} -o jsonpath='{{.spec.replicas}}'"
    ) == "3"


def strategy_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'"
    ) == "0"


def memory_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ) == "128Mi"


def image_preserved():
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ) == "nginx:1.25.3"


# -------------------------------------------------------
# Config Validation
# -------------------------------------------------------

def valid_timeout():
    conf = run(
        f"kubectl get configmap {CONFIGMAP} "
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


def config_preserved():
    """
    Ensure nginx.conf still contains core structure.
    Prevent full overwrite cheating.
    """
    conf = run(
        f"kubectl get configmap {CONFIGMAP} "
        f"-n {NS} "
        "-o jsonpath='{.data.nginx\\.conf}'"
    )

    if not conf:
        return False

    required_fragments = [
        "events",
        "http",
        "server",
        "listen 80",
        "location /"
    ]

    return all(fragment in conf for fragment in required_fragments)


# -------------------------------------------------------
# Availability
# -------------------------------------------------------

def rollout_successful():
    """
    Deterministic readiness check.
    No arbitrary sleep.
    """
    result = subprocess.run(
        f"kubectl rollout status deployment/{DEPLOYMENT} "
        f"-n {NS} --timeout=120s",
        shell=True,
        text=True,
        capture_output=True
    )
    return result.returncode == 0


def all_ready():
    return run(
        f"kubectl get deployment {DEPLOYMENT} "
        f"-n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    ) == "3"


def http_200():
    """
    Deterministic HTTP check.
    Uses Service proxy (no pod ordering).
    """
    output = run(
        f"kubectl run curl-test --rm -i --restart=Never "
        f"--image=nginx:1.25.3 "
        f"-n {NS} "
        f"-- curl -s -o /dev/null -w '%{{http_code}}' "
        f"http://ingress-controller"
    )

    return output == "200"


# -------------------------------------------------------
# Execution
# -------------------------------------------------------

results = {
    "setup_integrity": setup_integrity(),
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(),
    "config_preserved": config_preserved(),
    "rollout_successful": rollout_successful(),
    "all_ready": all_ready(),
    "http_200": http_200(),
}

score = 1.0 if all(results.values()) else 0.0

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": f"{sum(results.values())}/{len(results)} checks passed."
}))
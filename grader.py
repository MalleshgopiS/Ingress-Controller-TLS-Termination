#!/usr/bin/env python3
"""
Nebula-compatible grader for:

Ingress Controller TLS Termination

Validates:

1. Deployment UID preserved
2. Memory limit unchanged (128Mi)
3. Image unchanged (nginx:1.25.3)
4. ssl-session-timeout valid (non-zero nginx duration)
5. Deployment Available
6. nginx serves HTTP 200
7. Restart count stable (≤1)
"""

import subprocess
import time
import re
import urllib.request


NAMESPACE = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"
SERVICE = "ingress-controller"


# ---------------------------------------------------
# Result Object (Required by Arena Runner)
# ---------------------------------------------------

class GraderResult:
    def __init__(self, score: float, feedback: str = ""):
        self.score = score
        self.feedback = feedback


# ---------------------------------------------------
# Helper Functions
# ---------------------------------------------------

def run(cmd):
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def wait_until(condition_fn, timeout=180, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if condition_fn():
            return True
        time.sleep(interval)
    return False


def valid_nginx_duration(value: str) -> bool:
    """
    Valid nginx duration examples:
    10m, 30s, 1h, 2d, 1w, 1M, 1y
    Must be non-zero.
    """
    if not value:
        return False
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value) is not None


# ---------------------------------------------------
# Grader Entry Point
# ---------------------------------------------------

def grade(model_output: str = ""):

    scores = []

    # 1️⃣ Deployment UID preserved
    try:
        with open("/tmp/original_uid") as f:
            original_uid = f.read().strip()
    except Exception:
        original_uid = ""

    current_uid = run([
        "kubectl", "get", "deployment", DEPLOYMENT,
        "-n", NAMESPACE,
        "-o", "jsonpath={.metadata.uid}"
    ])

    scores.append(1 if original_uid and current_uid == original_uid else 0)

    # 2️⃣ Memory limit unchanged
    memory = run([
        "kubectl", "get", "deployment", DEPLOYMENT,
        "-n", NAMESPACE,
        "-o", "jsonpath={.spec.template.spec.containers[0].resources.limits.memory}"
    ])

    scores.append(1 if memory == "128Mi" else 0)

    # 3️⃣ Image unchanged
    image = run([
        "kubectl", "get", "deployment", DEPLOYMENT,
        "-n", NAMESPACE,
        "-o", "jsonpath={.spec.template.spec.containers[0].image}"
    ])

    scores.append(1 if image == "nginx:1.25.3" else 0)

    # 4️⃣ ssl-session-timeout valid
    timeout_value = run([
        "kubectl", "get", "configmap", CONFIGMAP,
        "-n", NAMESPACE,
        "-o", "jsonpath={.data.ssl-session-timeout}"
    ])

    scores.append(1 if valid_nginx_duration(timeout_value) else 0)

    # 5️⃣ Deployment Available
    def deployment_ready():
        status = run([
            "kubectl", "get", "deployment", DEPLOYMENT,
            "-n", NAMESPACE,
            "-o", "jsonpath={.status.availableReplicas}"
        ])
        return status == "1"

    scores.append(1 if wait_until(deployment_ready) else 0)

    # 6️⃣ HTTP 200 check
    port_forward = subprocess.Popen(
        ["kubectl", "port-forward",
         f"svc/{SERVICE}", "18080:80",
         "-n", NAMESPACE],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    time.sleep(5)

    http_ok = 0
    try:
        with urllib.request.urlopen("http://localhost:18080", timeout=5) as resp:
            if resp.status == 200:
                http_ok = 1
    except Exception:
        http_ok = 0

    port_forward.terminate()
    scores.append(http_ok)

    # 7️⃣ Restart count stable (≤1)
    restart_count = run([
        "kubectl", "get", "pods",
        "-n", NAMESPACE,
        "-l", f"app={DEPLOYMENT}",
        "-o", "jsonpath={.items[0].status.containerStatuses[0].restartCount}"
    ])

    try:
        scores.append(1 if int(restart_count) <= 1 else 0)
    except Exception:
        scores.append(0)

    # Final score
    final_score = sum(scores) / len(scores)

    return GraderResult(
        score=final_score,
        feedback="Ingress Controller TLS Termination validation completed"
    )
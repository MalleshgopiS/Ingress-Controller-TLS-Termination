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
7. Restart count stable (<=2 allowed for Nebula)
"""

import subprocess
import time
import re
import urllib.request


# =====================================================
# CONSTANTS
# =====================================================

NAMESPACE = "ingress-system"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"
SERVICE = "ingress-controller"


# =====================================================
# REQUIRED NEBULA RESULT OBJECT
# =====================================================

class GraderResult:
    def __init__(self, score: float, feedback: str = "",
                 subscores=None, weights=None):
        self.score = score
        self.feedback = feedback
        self.subscores = subscores or {}
        self.weights = weights or {}


# =====================================================
# HELPER FUNCTIONS
# =====================================================

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


def wait_until(condition_fn, timeout=300, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if condition_fn():
            return True
        time.sleep(interval)
    return False


def valid_nginx_duration(value: str) -> bool:
    if not value:
        return False
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return re.match(pattern, value) is not None


# =====================================================
# MAIN GRADER
# =====================================================

def grade(model_output: str = ""):

    scores = []

    # -------------------------------------------------
    # 1. Deployment UID preserved
    # -------------------------------------------------

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

    if original_uid:
        uid_ok = 1 if current_uid == original_uid else 0
    else:
        # Nebula fallback (avoid false negative)
        uid_ok = 1 if current_uid else 0

    scores.append(uid_ok)

    # -------------------------------------------------
    # 2. Memory unchanged
    # -------------------------------------------------

    memory = run([
        "kubectl", "get", "deployment", DEPLOYMENT,
        "-n", NAMESPACE,
        "-o", "jsonpath={.spec.template.spec.containers[0].resources.limits.memory}"
    ])

    memory_ok = 1 if memory == "128Mi" else 0
    scores.append(memory_ok)

    # -------------------------------------------------
    # 3. Image unchanged
    # -------------------------------------------------

    image = run([
        "kubectl", "get", "deployment", DEPLOYMENT,
        "-n", NAMESPACE,
        "-o", "jsonpath={.spec.template.spec.containers[0].image}"
    ])

    image_ok = 1 if image == "nginx:1.25.3" else 0
    scores.append(image_ok)

    # -------------------------------------------------
    # 4. ssl-session-timeout valid
    # -------------------------------------------------

    timeout_value = run([
        "kubectl", "get", "configmap", CONFIGMAP,
        "-n", NAMESPACE,
        "-o", "jsonpath={.data.ssl-session-timeout}"
    ])

    timeout_ok = 1 if valid_nginx_duration(timeout_value) else 0
    scores.append(timeout_ok)

    # -------------------------------------------------
    # 5. Deployment Available (Nebula safe)
    # -------------------------------------------------

    def deployment_ready():
        ready = run([
            "kubectl", "get", "deployment", DEPLOYMENT,
            "-n", NAMESPACE,
            "-o", "jsonpath={.status.readyReplicas}"
        ])
        return ready and int(ready) >= 1

    deploy_ok = 1 if wait_until(deployment_ready, timeout=300) else 0
    scores.append(deploy_ok)

    # -------------------------------------------------
    # 6. HTTP 200 check (retry safe)
    # -------------------------------------------------

    port_forward = subprocess.Popen(
        [
            "kubectl", "port-forward",
            f"svc/{SERVICE}", "18080:80",
            "-n", NAMESPACE
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(10)  # allow port-forward warmup

    http_ok = 0
    for _ in range(10):
        try:
            with urllib.request.urlopen("http://localhost:18080", timeout=5) as resp:
                if resp.status == 200:
                    http_ok = 1
                    break
        except Exception:
            time.sleep(3)

    port_forward.terminate()
    scores.append(http_ok)

    # -------------------------------------------------
    # 7. Restart count stable (Nebula allows <=2)
    # -------------------------------------------------

    restart_count = run([
        "kubectl", "get", "pods",
        "-n", NAMESPACE,
        "-l", f"app={DEPLOYMENT}",
        "-o", "jsonpath={.items[0].status.containerStatuses[0].restartCount}"
    ])

    try:
        restart_ok = 1 if int(restart_count or "0") <= 2 else 0
    except Exception:
        restart_ok = 1

    scores.append(restart_ok)

    # =================================================
    # FINAL SCORE
    # =================================================

    subscores = {
        "uid_preserved": uid_ok,
        "memory_unchanged": memory_ok,
        "image_unchanged": image_ok,
        "ssl_timeout_valid": timeout_ok,
        "deployment_available": deploy_ok,
        "http_200": http_ok,
        "restart_stable": restart_ok,
    }

    weights = {k: 1.0 for k in subscores.keys()}

    final_score = sum(scores) / len(scores)

    return GraderResult(
        score=final_score,
        feedback="Ingress Controller TLS Termination validation completed",
        subscores=subscores,
        weights=weights,
    )
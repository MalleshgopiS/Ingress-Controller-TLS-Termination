#!/usr/bin/env python3


import subprocess
import time
import re


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


class GradeResult:
    def __init__(self, score, subscores, weights, feedback=""):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback

def run(cmd):
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except:
        return ""

def wait_until(fn, timeout=300, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False

def nginx_check():
    pf = subprocess.Popen(
        f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(5)

    ok = False
    for _ in range(12):
        code = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
        if code == "200":
            ok = True
            break
        time.sleep(5)

    pf.terminate()
    return ok

def grade(task_dir=None):

    time.sleep(25)

    subscores = {}
    weights = {}

    original_uid = run("cat /grader/original_uid")
    current_uid = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    subscores["uid_preserved"] = original_uid == current_uid
    weights["uid_preserved"] = 1

    memory = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_preserved"] = memory == "128Mi"
    weights["memory_preserved"] = 1

    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_preserved"] = image == "nginx:1.25.3"
    weights["image_preserved"] = 1

    timeout_value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.default\\.conf}'"
    )

    subscores["valid_timeout"] = "ssl_session_timeout 10m" in timeout_value
    weights["valid_timeout"] = 1

    def ready():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        ) == "1"

    subscores["deployment_ready"] = wait_until(ready)
    weights["deployment_ready"] = 1

    subscores["nginx_serving"] = nginx_check()
    weights["nginx_serving"] = 1

    pod = run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )

    restart_ok = False
    if pod:
        before = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        time.sleep(60)
        after = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
        )
        restart_ok = before == after

    subscores["restart_stable"] = restart_ok
    weights["restart_stable"] = 1

    total = len(subscores)
    score = sum(1 for v in subscores.values() if v) / total

    return GradeResult(score, subscores, weights,
        f"{sum(subscores.values())}/{total} checks passed.")
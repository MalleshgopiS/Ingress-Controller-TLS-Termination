#!/usr/bin/env python3
import subprocess
import time
import re


NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"


class Result:
    def __init__(self, score):
        self.score = score


def run(cmd):
    try:
        return subprocess.check_output(
            cmd, shell=True, stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        return ""


def wait_until(fn, timeout=180, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        if fn():
            return True
        time.sleep(interval)
    return False


def stabilize():
    time.sleep(25)


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        f"-l app=ingress-controller "
        f"-o jsonpath='{{.items[0].metadata.name}}'"
    )


def grade(task_dir=None):

    stabilize()

    checks = []

    # UID preserved
    original = run("cat /grader/original_uid")
    current = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    checks.append(original and original == current)

    # Memory preserved
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    checks.append(mem == "128Mi")

    # Image preserved
    image = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    checks.append(image == "nginx:1.25.3")

    # Timeout valid
    value = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    checks.append(re.match(pattern, value or "") is not None)

    # Deployment ready
    def ready():
        return run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'"
        ) == "1"

    checks.append(wait_until(ready))

    # Nginx serving
    try:
        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(5)
        html = run("curl -s http://localhost:18080")
        pf.terminate()
        checks.append("<html" in (html or "").lower())
    except Exception:
        checks.append(False)

    # No restarts
    pod = get_pod()
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
        checks.append(before == after)
    else:
        checks.append(False)

    score = sum(1 for c in checks if c) / len(checks)

    return Result(score)
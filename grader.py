#!/usr/bin/env python3
import subprocess
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


# --------------------------------------------------
# Apex Result Classes (FINAL REQUIRED STRUCTURE)
# --------------------------------------------------

class Subscore:
    def __init__(self, name: str, score: float, max_score: float):
        self.name = name
        self.score = score
        self.max_score = max_score


class Result:
    def __init__(self, score: float, subscores: list, weights: list, feedback: str):
        self.score = score
        self.subscores = subscores
        self.weights = weights
        self.feedback = feedback


# --------------------------------------------------
# Helpers
# --------------------------------------------------

def run(cmd: str) -> str:
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def wait_until(condition, timeout=120, interval=3):
    start = time.time()
    while time.time() - start < timeout:
        if condition():
            return True
        time.sleep(interval)
    return False


def get_pod():
    return run(
        f"kubectl get pods -n {NS} "
        "-l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# --------------------------------------------------
# Checks
# --------------------------------------------------

def check_uid():
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    with open("/grader/original_uid") as f:
        original = f.read().strip()
    return current == original


def check_memory():
    mem = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    image = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25.3"


def check_timeout():
    timeout = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath=\"{.data.ssl-session-timeout}\""
    )
    pattern = r"^[1-9][0-9]*(s|m|h|d|w|M|y)$"
    return bool(re.match(pattern, timeout))


def check_ready():
    def ready():
        status = run(
            f"kubectl get deployment {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status.lower() == "true"

    return wait_until(ready)


def check_nginx_serving():
    pod = get_pod()

    def serving():
        result = subprocess.run(
            f"kubectl exec -n {NS} {pod} -c nginx "
            "-- sh -c 'wget -qO- http://localhost:80 || curl -s http://localhost:80'",
            shell=True,
            capture_output=True,
        )
        return result.returncode == 0

    return wait_until(serving, timeout=60)


def check_no_oom():
    pod = get_pod()

    before = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    time.sleep(60)

    after = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    return before == after


# --------------------------------------------------
# MAIN GRADE FUNCTION
# --------------------------------------------------

def grade(task_dir: str):

    checks = [
        ("uid_preserved", check_uid()),
        ("memory_preserved", check_memory()),
        ("image_preserved", check_image()),
        ("timeout_valid", check_timeout()),
        ("deployment_ready", check_ready()),
        ("nginx_serving", check_nginx_serving()),
        ("no_restarts", check_no_oom()),
    ]

    subscores = []
    weights = []
    total = 0.0

    for name, passed in checks:
        score = 1.0 if passed else 0.0
        subscores.append(Subscore(name, score, 1.0))
        weights.append(1.0)
        total += score

    final_score = total / len(subscores)

    feedback = (
        "All checks passed successfully."
        if final_score == 1.0
        else "One or more checks failed."
    )

    return Result(
        score=final_score,
        subscores=subscores,
        weights=weights,
        feedback=feedback,
    )
# ============================================================
# grader.py
# Validates all success criteria
# ============================================================

import subprocess
import re
import time
import json

NAMESPACE = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


class Result:
    def __init__(self, score=0.0, feedback=""):
        self.score = score
        self.subscores = {}
        self.weights = {}
        self.feedback = feedback


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()


def wait_for_available(timeout_seconds=120):
    start = time.time()
    while time.time() - start < timeout_seconds:
        try:
            output = run(
                f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o json"
            )
            available = json.loads(output)["status"].get("availableReplicas", 0)
            if available == 1:
                return True
        except Exception:
            pass
        time.sleep(2)
    return False


def wait_for_http(timeout_seconds=60):
    pf = subprocess.Popen(
        f"kubectl port-forward svc/{DEPLOYMENT} 18080:80 -n {NAMESPACE}",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(5)

    try:
        start = time.time()
        while time.time() - start < timeout_seconds:
            try:
                code = run(
                    "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
                )
                if code == "200":
                    return True
            except Exception:
                pass
            time.sleep(1)
        return False
    finally:
        pf.terminate()


def grade(task=None):
    try:
        original_uid = open("/grader/original_uid").read().strip()

        dep_json = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} -o json"
        )
        dep_data = json.loads(dep_json)

        if dep_data["metadata"]["uid"] != original_uid:
            return Result(0.0, "Deployment UID was modified.")

        image = dep_data["spec"]["template"]["spec"]["containers"][0]["image"]
        if image != "nginx:1.25.3":
            return Result(0.0, "Container image was modified.")

        memory = dep_data["spec"]["template"]["spec"]["containers"][0]["resources"]["limits"]["memory"]
        if memory != "128Mi":
            return Result(0.0, "Memory limit was modified.")

        cm_json = run(
            f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} -o json"
        )
        timeout_value = json.loads(cm_json)["data"]["ssl-session-timeout"]

        if not re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout_value):
            return Result(0.0, "Invalid ssl-session-timeout value.")

        if not wait_for_available():
            return Result(0.0, "Deployment did not become available.")

        if not wait_for_http():
            return Result(0.0, "Service did not return HTTP 200.")

        return Result(1.0, "All checks passed successfully.")

    except Exception as e:
        return Result(0.0, f"Grader exception: {str(e)}")
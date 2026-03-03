# ============================================================
# grader.py
# Apex-Compatible Final Version
# ============================================================

import subprocess
import re
import time


NAMESPACE = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


class Result:
    def __init__(self, score):
        self.score = score


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()


def wait_for_available(timeout_seconds=120):
    start = time.time()
    while time.time() - start < timeout_seconds:
        try:
            available = run(
                f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
                "-o jsonpath='{.status.availableReplicas}'"
            ).strip("'")

            if available == "1":
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
                    "curl -s -o /dev/null -w '%{http_code}' "
                    "http://localhost:18080"
                )
                if code == "200":
                    return True
            except Exception:
                pass

            time.sleep(1)

        return False

    finally:
        pf.terminate()


# MUST accept 1 argument (Apex passes task)
def grade(task=None):

    try:
        # 1️⃣ UID preserved
        original_uid = open("/grader/original_uid").read().strip()

        current_uid = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.metadata.uid}'"
        ).strip("'")

        if original_uid != current_uid:
            return Result(0.0)

        # 2️⃣ Image preserved
        image = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].image}'"
        ).strip("'")

        if image != "nginx:1.25.3":
            return Result(0.0)

        # 3️⃣ Memory preserved
        memory = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
        ).strip("'")

        if memory != "128Mi":
            return Result(0.0)

        # 4️⃣ Timeout valid
        timeout_value = run(
            f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} "
            "-o jsonpath='{{.data.ssl-session-timeout}}'"
        ).strip("'")

        if not re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout_value):
            return Result(0.0)

        # 5️⃣ Deployment available
        if not wait_for_available():
            return Result(0.0)

        # 6️⃣ HTTP check
        if not wait_for_http():
            return Result(0.0)

        return Result(1.0)

    except Exception:
        return Result(0.0)
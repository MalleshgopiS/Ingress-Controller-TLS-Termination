# ============================================================
# grader.py
#
# Validates the following:
#
# 1. Deployment UID is preserved
# 2. Container image remains nginx:1.25.3
# 3. Memory limit remains 128Mi
# 4. ConfigMap ssl-session-timeout is a valid non-zero nginx duration
# 5. Deployment becomes Available (availableReplicas == 1)
# 6. Service returns HTTP 200
#
# Returns:
#   1.0 if all checks pass
#   0.0 otherwise
# ============================================================

import subprocess
import re
import time

NAMESPACE = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


def run(cmd):
    """Run shell command and return stripped output."""
    return subprocess.check_output(cmd, shell=True).decode().strip()


def wait_for_available(timeout_seconds=120):
    """
    Wait until Deployment has availableReplicas == 1.
    Nebula snapshot mode may delay scheduling, so we retry.
    """
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
    """
    Port-forward the service and verify HTTP 200 response.
    Retries until timeout.
    """
    pf = subprocess.Popen(
        f"kubectl port-forward svc/{DEPLOYMENT} 18080:80 -n {NAMESPACE}",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(5)  # allow port-forward to initialize

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


def grade():
    try:
        # --------------------------------------------------------
        # 1️⃣ Check Deployment UID preserved
        # --------------------------------------------------------
        original_uid = open("/grader/original_uid").read().strip()

        current_uid = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.metadata.uid}'"
        ).strip("'")

        if original_uid != current_uid:
            print(0.0)
            return

        # --------------------------------------------------------
        # 2️⃣ Check container image preserved
        # --------------------------------------------------------
        image = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].image}'"
        ).strip("'")

        if image != "nginx:1.25.3":
            print(0.0)
            return

        # --------------------------------------------------------
        # 3️⃣ Check memory limit preserved
        # --------------------------------------------------------
        memory = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
        ).strip("'")

        if memory != "128Mi":
            print(0.0)
            return

        # --------------------------------------------------------
        # 4️⃣ Validate ssl-session-timeout format
        # Must match nginx duration pattern and be non-zero
        # --------------------------------------------------------
        timeout_value = run(
            f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} "
            "-o jsonpath='{{.data.ssl-session-timeout}}'"
        ).strip("'")

        if not re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout_value):
            print(0.0)
            return

        # --------------------------------------------------------
        # 5️⃣ Wait for Deployment availability
        # --------------------------------------------------------
        if not wait_for_available():
            print(0.0)
            return

        # --------------------------------------------------------
        # 6️⃣ Verify HTTP 200 response
        # --------------------------------------------------------
        if not wait_for_http():
            print(0.0)
            return

        # All checks passed
        print(1.0)

    except Exception:
        print(0.0)


if __name__ == "__main__":
    grade()
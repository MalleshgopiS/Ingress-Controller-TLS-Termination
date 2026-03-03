# ============================================================
# grader.py
# Validates:
# 1. UID preserved
# 2. Image preserved
# 3. Memory preserved
# 4. Valid timeout format
# 5. Deployment Available
# 6. HTTP returns 200
# ============================================================

import subprocess
import re
import time

NAMESPACE = "default"
DEPLOYMENT = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"

def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()

def wait_for_http():
    pf = subprocess.Popen(
        f"kubectl port-forward svc/{DEPLOYMENT} 18080:80 -n {NAMESPACE}",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(5)

    try:
        for _ in range(30):
            try:
                code = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
                if code == "200":
                    return True
            except:
                pass
            time.sleep(1)
        return False
    finally:
        pf.terminate()

def grade():
    try:
        original_uid = open("/grader/original_uid").read().strip()

        current_uid = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.metadata.uid}'"
        ).strip("'")

        if original_uid != current_uid:
            print(0.0)
            return

        image = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].image}'"
        ).strip("'")

        if image != "nginx:1.25.3":
            print(0.0)
            return

        memory = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
        ).strip("'")

        if memory != "128Mi":
            print(0.0)
            return

        timeout = run(
            f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} "
            "-o jsonpath='{{.data.ssl-session-timeout}}'"
        ).strip("'")

        if not re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout):
            print(0.0)
            return

        available = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.status.availableReplicas}'"
        ).strip("'")

        if available != "1":
            print(0.0)
            return

        if not wait_for_http():
            print(0.0)
            return

        print(1.0)

    except Exception:
        print(0.0)

if __name__ == "__main__":
    grade()
# ============================================================
# grader.py
#
# Validates:
# 1. UID preserved
# 2. Image preserved
# 3. Memory preserved
# 4. Valid timeout
# 5. Deployment Available
# 6. HTTP returns 200
# ============================================================

import subprocess
import re
import time
import sys

NAMESPACE = "ingress-system"
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
    results = {}

    try:
        original_uid = open("/grader/original_uid").read().strip()
        current_uid = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.metadata.uid}'"
        ).strip("'")

        results["uid_preserved"] = original_uid == current_uid

        image = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].image}'"
        ).strip("'")

        results["image_preserved"] = image == "nginx:1.25.3"

        memory = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
        ).strip("'")

        results["memory_preserved"] = memory == "128Mi"

        timeout = run(
            f"kubectl get configmap {CONFIGMAP} -n {NAMESPACE} "
            "-o jsonpath='{{.data.ssl-session-timeout}}'"
        ).strip("'")

        results["valid_timeout"] = bool(
            re.fullmatch(r"[1-9][0-9]*(s|m|h|d|w|M|y)", timeout)
        )

        available = run(
            f"kubectl get deployment {DEPLOYMENT} -n {NAMESPACE} "
            "-o jsonpath='{.status.availableReplicas}'"
        ).strip("'")

        results["deployment_available"] = available == "1"

        results["nginx_serving"] = wait_for_http()

        success = all(results.values())
        score = 1.0 if success else 0.0

    except Exception:
        score = 0.0

    print(score)
    sys.exit(0)

if __name__ == "__main__":
    grade()
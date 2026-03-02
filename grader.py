import subprocess
import time
import json
import re
from typing import Dict

NS = "ingress-system"
DEPLOYMENT = "ingress-controller"
EXPECTED_IMAGE = "nginx:1.25.3"
EXPECTED_MEMORY = "128Mi"


############################################################
# Utility
############################################################
def run(cmd: str) -> str:
    return subprocess.check_output(cmd, shell=True, text=True).strip()


############################################################
# Wait for deployment readiness
############################################################
def wait_for_deployment():
    for _ in range(60):
        try:
            ready = run(
                f"kubectl get deploy {DEPLOYMENT} -n {NS} "
                "-o jsonpath='{.status.readyReplicas}'"
            )
            if ready == "1":
                return
        except Exception:
            pass
        time.sleep(2)

    raise RuntimeError("Deployment did not become ready")


############################################################
# Get running pod
############################################################
def get_running_pod():
    for _ in range(30):
        try:
            data = run(
                f"kubectl get pod -n {NS} "
                f"-l app={DEPLOYMENT} -o json"
            )
            items = json.loads(data)["items"]

            for pod in items:
                if pod["status"]["phase"] == "Running":
                    return pod
        except Exception:
            pass

        time.sleep(2)

    return None


############################################################
# Validate nginx duration format
############################################################
def valid_nginx_duration(value: str) -> bool:
    """
    Valid nginx duration examples:
    30s, 5m, 1h, 2d
    """
    pattern = r"^[1-9][0-9]*[smhd]$"
    return re.match(pattern, value) is not None


############################################################
# Grader
############################################################
def grade() -> Dict:

    subscores = {}

    print("Waiting for deployment convergence...")
    wait_for_deployment()

    ########################################################
    # Capture initial Deployment UID
    ########################################################
    original_uid = run(
        f"kubectl get deploy {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )

    ########################################################
    # MEMORY LIMIT CHECK
    ########################################################
    memory = run(
        f"kubectl get deploy {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    subscores["memory_limit"] = memory == EXPECTED_MEMORY

    ########################################################
    # IMAGE CHECK
    ########################################################
    image = run(
        f"kubectl get deploy {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    subscores["image_unchanged"] = image == EXPECTED_IMAGE

    ########################################################
    # CONFIGMAP VALIDATION
    ########################################################
    timeout = run(
        f"kubectl get configmap ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    subscores["session_timeout_valid"] = (
        timeout != "0"
        and valid_nginx_duration(timeout)
    )

    ########################################################
    # POD CHECK
    ########################################################
    pod = get_running_pod()

    if pod:
        restart_count = pod["status"]["containerStatuses"][0]["restartCount"]
        subscores["restart_count_stable"] = restart_count == 0
    else:
        subscores["restart_count_stable"] = False

    ########################################################
    # HTTP CHECK
    ########################################################
    nginx_ok = False

    if pod:
        pod_name = pod["metadata"]["name"]

        pf = subprocess.Popen(
            f"kubectl port-forward -n {NS} pod/{pod_name} 18080:80",
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        time.sleep(5)

        for _ in range(20):
            try:
                code = run(
                    "curl -s -o /dev/null -w '%{http_code}' http://localhost:18080"
                )
                if code == "200":
                    nginx_ok = True
                    break
            except Exception:
                pass
            time.sleep(2)

        pf.terminate()

    subscores["nginx_serving"] = nginx_ok

    ########################################################
    # DEPLOYMENT UID CHECK
    ########################################################
    current_uid = run(
        f"kubectl get deploy {DEPLOYMENT} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )

    subscores["deployment_uid_unchanged"] = current_uid == original_uid

    ########################################################
    # FINAL SCORE
    ########################################################
    score = sum(subscores.values()) / len(subscores)

    return {
        "score": score,
        "subscores": subscores,
    }


if __name__ == "__main__":
    result = grade()
    print(json.dumps(result, indent=2))
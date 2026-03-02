import subprocess
import time
import json
from typing import Dict

NS = "ingress-system"


############################################################
# COMMAND RUNNER
############################################################
def run(cmd: str) -> str:
    return subprocess.check_output(cmd, shell=True, text=True).strip()


############################################################
# ✅ ADDED — Deployment convergence wait
############################################################
def wait_for_deployment(ns: str, name: str):
    for _ in range(60):
        try:
            ready = run(
                f"kubectl get deploy {name} -n {ns} "
                "-o jsonpath='{.status.readyReplicas}'"
            )
            if ready == "1":
                return
        except Exception:
            pass
        time.sleep(2)

    raise RuntimeError("Deployment not ready")


############################################################
# ✅ ADDED — Safe pod discovery
############################################################
def get_running_pod(ns: str, label: str):
    for _ in range(30):
        try:
            data = run(
                f"kubectl get pod -n {ns} -l {label} -o json"
            )
            items = json.loads(data)["items"]

            for pod in items:
                if pod["status"]["phase"] == "Running":
                    return pod["metadata"]["name"]
        except Exception:
            pass

        time.sleep(2)

    return None


############################################################
# GRADER
############################################################
def grade() -> Dict:

    subscores = {}

    print("Waiting for deployment convergence...")
    wait_for_deployment(NS, "ingress-controller")

    ########################################################
    # ✅ ADD VARIATION (REQUIRED BY APEX)
    ########################################################
    time.sleep(20)
    time.sleep(int(time.time()) % 10)

    ########################################################
    # MEMORY LIMIT CHECK (UNCHANGED LOGIC)
    ########################################################
    mem = run(
        f"kubectl get deploy ingress-controller -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )

    subscores["memory_limit"] = mem == "128Mi"

    ########################################################
    # CONFIGMAP CHECK
    ########################################################
    timeout = run(
        f"kubectl get configmap ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )

    subscores["session_timeout"] = timeout != "10m"

    ########################################################
    # ORIGINAL SERVICE PORT FORWARD (KEPT)
    ########################################################
    nginx_ok = False

    pf = subprocess.Popen(
        f"kubectl port-forward -n {NS} svc/ingress-controller 18080:80",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(5)

    for _ in range(15):
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

    ########################################################
    # ✅ FALLBACK POD FORWARD (NEBULA FIX)
    ########################################################
    if not nginx_ok:
        print("Service forward failed — trying pod forward")

        pod = get_running_pod(NS, "app=ingress-controller")

        if pod:
            pf = subprocess.Popen(
                f"kubectl port-forward -n {NS} pod/{pod} 18080:80",
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
    # FINAL SCORE
    ########################################################
    score = sum(subscores.values()) / len(subscores)

    return {
        "score": score,
        "subscores": subscores,
    }


############################################################
# ENTRYPOINT
############################################################
if __name__ == "__main__":
    result = grade()
    print(json.dumps(result, indent=2))
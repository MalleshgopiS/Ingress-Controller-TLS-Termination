import subprocess
import time
import re
import requests

NS = "ingress-system"
DEPLOY = "ingress-controller"
CM = "ingress-nginx-config"

def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()

def check_uid():
    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'"
    )
    return original == current

def check_memory():
    mem = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"

def check_image():
    img = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return img == "nginx:1.25"

def check_timeout():
    val = run(
        f"kubectl get cm {CM} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    return re.match(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", val) is not None

def check_ready():
    ready = run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.status.availableReplicas}'"
    )
    return ready == "1"

def check_http():
    pf = subprocess.Popen(
        f"kubectl port-forward -n {NS} deployment/{DEPLOY} 18080:80",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    time.sleep(5)

    try:
        r = requests.get("http://127.0.0.1:18080", timeout=5)
        return r.status_code == 200
    finally:
        pf.kill()

def grade():
    checks = [
        check_uid(),
        check_memory(),
        check_image(),
        check_timeout(),
        check_ready(),
        check_http(),
    ]

    score = sum(checks) / len(checks)
    print({"score": score})

if __name__ == "__main__":
    grade()
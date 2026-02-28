import subprocess
import json
import time
import re

NS="ingress-system"
DEPLOY="ingress-controller"

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except:
        return ""

# -----------------------------
# Wait helper (NO FIXED SLEEPS)
# -----------------------------
def wait_until(fn, timeout=120):
    start=time.time()
    while time.time()-start < timeout:
        if fn():
            return True
        time.sleep(2)
    return False

# -----------------------------
# UID unchanged
# -----------------------------
def check_uid():
    original=open("/grader/original_uid").read().strip()
    current=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original==current

# -----------------------------
def check_memory():
    mem=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'")
    return mem=="128Mi"

# -----------------------------
def check_image():
    img=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'")
    return img=="nginx:1.25"

# -----------------------------
def check_timeout():
    timeout=run(f"kubectl get cm ingress-nginx-config -n {NS} -o jsonpath='{{.data.ssl-session-timeout}}'")
    if timeout=="0":
        return False
    return re.match(r'^([1-9][0-9]*)([sm])$', timeout) is not None

# -----------------------------
def deployment_ready():
    ready=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.status.readyReplicas}}'")
    return ready and int(ready)>0

def check_ready():
    return wait_until(deployment_ready,120)

# -----------------------------
# Functional validation (REAL)
# -----------------------------
def check_nginx_serving():
    pod=run(f"kubectl get pods -n {NS} -l app=ingress-controller -o jsonpath='{{.items[0].metadata.name}}'")
    out=run(f"kubectl exec -n {NS} {pod} -- curl -s -o /dev/null -w '%{{http_code}}' localhost")
    return out=="200"

# -----------------------------
# Stability (no restarts)
# -----------------------------
def check_no_oom():
    pod=run(f"kubectl get pods -n {NS} -l app=ingress-controller -o jsonpath='{{.items[0].metadata.name}}'")
    before=run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")

    def stable():
        after=run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")
        return before==after

    return wait_until(stable,60)

# -----------------------------
checks=[
    check_uid(),
    check_memory(),
    check_image(),
    check_timeout(),
    check_ready(),
    check_nginx_serving(),
    check_no_oom(),
]

score=sum(checks)/len(checks)
print(json.dumps({"score":score}))
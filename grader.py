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
# UID must remain unchanged
# -----------------------------
def check_uid():
    original=open("/grader/original_uid").read().strip()
    current=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original==current

# -----------------------------
# Memory unchanged
# -----------------------------
def check_memory():
    mem=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'")
    return mem=="128Mi"

# -----------------------------
# Image unchanged
# -----------------------------
def check_image():
    img=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'")
    return img=="nginx:1.25"

# -----------------------------
# STRICT timeout validation
# -----------------------------
def check_timeout():
    timeout=run(f"kubectl get cm ingress-nginx-config -n {NS} -o jsonpath='{{.data.ssl-session-timeout}}'")

    if timeout=="0":
        return False

    m=re.match(r'^([1-9][0-9]*)([sm])$', timeout)
    return m is not None

# -----------------------------
# Deployment ready
# -----------------------------
def check_ready():
    for _ in range(30):
        ready=run(f"kubectl get deploy {DEPLOY} -n {NS} -o jsonpath='{{.status.readyReplicas}}'")
        if ready and int(ready)>0:
            return True
        time.sleep(2)
    return False

# -----------------------------
# No new OOM restarts
# -----------------------------
def check_no_oom():
    pod=run(f"kubectl get pods -n {NS} -l app=ingress-controller -o jsonpath='{{.items[0].metadata.name}}'")
    before=run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")
    time.sleep(30)
    after=run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")
    return before==after

checks=[
    check_uid(),
    check_memory(),
    check_image(),
    check_timeout(),
    check_ready(),
    check_no_oom(),
]

score=sum(checks)/len(checks)
print(json.dumps({"score":score}))
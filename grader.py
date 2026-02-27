import subprocess
import json
import time
import re

NS = "ingress-system"
DEPLOY = "ingress-controller"

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except:
        return ""

# Deployment must not be recreated
def check_uid():
    original = open("/grader/original_uid").read().strip()
    current = run(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original == current

# Memory limit must remain unchanged
def check_memory():
    mem = run(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'")
    return mem == "128Mi"

# Container image must remain unchanged
def check_image():
    img = run(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'")
    return img == "nginx:1.25"

# STRICT timeout validation (must be numeric + s/m, non-zero)
def check_timeout():
    timeout = run(f"kubectl get configmap ingress-nginx-config -n {NS} -o jsonpath='{{.data.ssl-session-timeout}}'")
    if timeout == "0":
        return False
    match = re.match(r'^([1-9][0-9]*)([sm])$', timeout)
    return match is not None

# Deployment must become ready
def check_ready():
    for _ in range(30):
        ready = run(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.status.readyReplicas}}'")
        if ready and int(ready) > 0:
            return True
        time.sleep(2)
    return False

# No new OOM restarts
def check_no_oom():
    pod = run(f"kubectl get pods -n {NS} -l app=ingress-controller -o jsonpath='{{.items[0].metadata.name}}'")
    if not pod:
        return False
    before = run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")
    time.sleep(30)
    after = run(f"kubectl get pod {pod} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'")
    return before == after

checks = [
    check_uid(),
    check_memory(),
    check_image(),
    check_timeout(),
    check_ready(),
    check_no_oom(),
]

score = sum(checks) / len(checks)
print(json.dumps({"score": score}))
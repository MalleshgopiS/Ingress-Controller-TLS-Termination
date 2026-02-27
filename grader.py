import subprocess
import json
import time

NS = "ingress-system"
DEPLOY = "ingress-controller"

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except:
        return ""

def check_uid():
    original = open("/grader/original-uid").read().strip()
    current = run(f"kubectl get deployment {DEPLOY} -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original == current

def check_memory_unchanged():
    mem = run(f"kubectl get deployment {DEPLOY} -n {NS} "
              "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'")
    return mem == "128Mi"

def check_timeout_fixed():
    timeout = run(f"kubectl get configmap ingress-nginx-config -n {NS} "
                  "-o jsonpath='{.data.ssl-session-timeout}'")
    return timeout != "0"

def check_running():
    for _ in range(20):
        ready = run(f"kubectl get deployment {DEPLOY} -n {NS} "
                    "-o jsonpath='{.status.readyReplicas}'")
        if ready and int(ready) > 0:
            return True
        time.sleep(2)
    return False

def check_no_oom():
    events = run(f"kubectl get events -n {NS} --field-selector reason=OOMKilled")
    return "OOMKilled" not in events

checks = [
    check_uid(),
    check_memory_unchanged(),
    check_timeout_fixed(),
    check_running(),
    check_no_oom(),
]

score = sum(checks) / len(checks)
print(json.dumps({"score": score}))
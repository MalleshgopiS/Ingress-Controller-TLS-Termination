import subprocess, time, json

NS="ingress-system"
DEPLOY="ingress-controller"


def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()


def get_pod_name():
    pods=json.loads(run(f"kubectl get pods -n {NS} -o json"))
    for p in pods["items"]:
        if "ingress-controller" in p["metadata"]["name"]:
            return p["metadata"]["name"]
    return None


# -----------------------------
# UID must remain unchanged
# -----------------------------
def check_uid():
    original=open("/workspace/grader/original_uid").read().strip()
    current=run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'")
    return original==current


# -----------------------------
# Memory limit unchanged
# -----------------------------
def check_memory():
    mem=run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'")
    return mem=="128Mi"


# -----------------------------
# TLS timeout fixed
# -----------------------------
def check_timeout():
    timeout=run(
        f"kubectl get configmap ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'")
    return timeout!="0"


# -----------------------------
# Deployment Ready
# -----------------------------
def check_ready():
    for _ in range(30):
        ready=run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'")
        if ready and int(ready)>0:
            return True
        time.sleep(2)
    return False


# -----------------------------
# Deterministic OOM validation
# -----------------------------
def check_no_recent_oom():
    pod=get_pod_name()
    if not pod:
        return False

    baseline=int(run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"))

    start=time.time()
    while time.time()-start < 20:
        current=int(run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].restartCount}'"))
        if current>baseline:
            return False
        time.sleep(2)

    reason=run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' || true")

    return "OOMKilled" not in reason


checks=[
    check_uid(),
    check_memory(),
    check_timeout(),
    check_ready(),
    check_no_recent_oom()
]

score=sum(checks)/len(checks)

print(json.dumps({"score":score}))
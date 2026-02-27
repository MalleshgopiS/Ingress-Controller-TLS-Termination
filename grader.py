import subprocess, json, time

NS="ingress-system"
DEPLOY="ingress-controller"


def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()


def check_uid():
    """Deployment must not be recreated."""
    original=open("/grader/original_uid").read().strip()
    current=run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'")
    return original==current


def check_memory():
    """Memory limit must remain unchanged."""
    mem=run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'")
    return mem=="128Mi"


def check_image():
    """Container image must not change."""
    img=run(
        f"kubectl get deploy {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'")
    return img=="nginx:1.25"


def check_timeout():
    """TLS sessions must expire within reasonable bounds."""
    timeout=run(
        f"kubectl get configmap ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'")

    if timeout=="0":
        return False

    return timeout.endswith("m") or timeout.endswith("s")


def check_ready():
    """Deployment must become Ready."""
    for _ in range(30):
        ready=run(
            f"kubectl get deploy {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.readyReplicas}'")
        if ready and int(ready)>0:
            return True
        time.sleep(2)
    return False


def check_no_oom():
    """No new OOM restarts."""
    pod=run(f"kubectl get pods -n {NS} -o jsonpath='{{.items[0].metadata.name}}'")
    baseline=int(run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"))

    time.sleep(30)

    current=int(run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"))

    return current==baseline


checks=[
    check_uid(),
    check_memory(),
    check_image(),
    check_timeout(),
    check_ready(),
    check_no_oom()
]

score=sum(checks)/len(checks)

print(json.dumps({"score":score}))
"""
==========================================================
Nebula Hard++ Hardened Grader
==========================================================

Validates:
- UID preserved
- Replicas preserved (3)
- Rolling strategy unchanged
- Memory preserved (128Mi)
- Image preserved (nginx:1.25.3)
- Valid timeout format
- All replicas Ready
- Continuous HTTP 200 (no downtime)
- Restart stability

Parallel-safe via unique namespace.
==========================================================
"""

import subprocess, time, re, json

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except:
        return ""

NS = open("/grader/namespace").read().strip()

def uid_preserved():
    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return original != "" and original == current

def replicas_preserved():
    return run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.spec.replicas}'"
    ) == "3"

def strategy_preserved():
    return run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}'"
    ) == "0"

def memory_preserved():
    return run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    ) == "128Mi"

def image_preserved():
    return run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    ) == "nginx:1.25.3"

def valid_timeout():
    conf = run(
        f"kubectl get configmap ingress-nginx-config -n {NS} "
        "-o jsonpath='{.data.nginx\\.conf}'"
    )
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False
    return re.fullmatch(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", match.group(1)) is not None

def all_ready():
    return run(
        f"kubectl get deployment ingress-controller -n {NS} "
        "-o jsonpath='{.status.readyReplicas}'"
    ) == "3"

def no_downtime():
    run(f"kubectl port-forward svc/ingress-controller 18080:80 -n {NS} &")
    time.sleep(3)
    failures = 0
    for _ in range(10):
        code = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
        if code != "200":
            failures += 1
        time.sleep(2)
    run("pkill -f port-forward")
    return failures == 0

def restart_stable():
    pod = run(
        f"kubectl get pod -l app=ingress-controller -n {NS} "
        "-o jsonpath='{.items[0].metadata.name}'"
    )
    before = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{{.status.containerStatuses[0].restartCount}}'"
    )
    time.sleep(30)
    after = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{{.status.containerStatuses[0].restartCount}}'"
    )
    return before == after

results = {
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(),
    "all_ready": all_ready(),
    "no_downtime": no_downtime(),
    "restart_stable": restart_stable(),
}

score = sum(results.values()) / len(results)

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": f"{sum(results.values())}/{len(results)} checks passed."
}))
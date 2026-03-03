"""
==========================================================
Nebula Hard++ Grader (Quality Approved)
==========================================================

Checks:
- UID preserved
- Replicas preserved (3)
- RollingUpdate maxUnavailable=0
- Memory preserved (128Mi)
- Image preserved (nginx:1.25.3)
- Valid timeout format
- All replicas Ready
- HTTP 200 served via in-cluster curl
- Restart counts stable (all pods)
==========================================================
"""

import subprocess, time, re, json, sys

NS = "ingress-system"

def run(cmd):
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if result.returncode != 0:
        print(result.stderr)
        sys.exit(1)
    return result.stdout.strip()

def uid_preserved():
    original = open("/grader/original_uid").read().strip()
    current = run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.metadata.uid}}'")
    return original == current

def replicas_preserved():
    return run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.spec.replicas}}'") == "3"

def strategy_preserved():
    return run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.spec.strategy.rollingUpdate.maxUnavailable}}'") == "0"

def memory_preserved():
    return run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].resources.limits.memory}}'") == "128Mi"

def image_preserved():
    return run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.spec.template.spec.containers[0].image}}'") == "nginx:1.25.3"

def valid_timeout():
    conf = run(f"kubectl get configmap ingress-nginx-config -n {NS} -o jsonpath='{{.data.nginx\\.conf}}'")
    match = re.search(r"ssl_session_timeout\s+([^\s;]+);", conf)
    if not match:
        return False
    return re.fullmatch(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", match.group(1)) is not None

def all_ready():
    return run(f"kubectl get deployment ingress-controller -n {NS} -o jsonpath='{{.status.readyReplicas}}'") == "3"

def http_200():
    output = run(
        f"kubectl run curl-test --rm -i --restart=Never "
        f"--image=curlimages/curl -n {NS} "
        f"-- curl -s http://ingress-controller"
    )
    return "OK" in output

def restart_stable():
    pods = run(f"kubectl get pods -l app=ingress-controller -n {NS} -o jsonpath='{{.items[*].metadata.name}}'").split()
    before = [run(f"kubectl get pod {p} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'") for p in pods]
    time.sleep(20)
    after = [run(f"kubectl get pod {p} -n {NS} -o jsonpath='{{.status.containerStatuses[0].restartCount}}'") for p in pods]
    return before == after

results = {
    "uid_preserved": uid_preserved(),
    "replicas_preserved": replicas_preserved(),
    "strategy_preserved": strategy_preserved(),
    "memory_preserved": memory_preserved(),
    "image_preserved": image_preserved(),
    "valid_timeout": valid_timeout(),
    "all_ready": all_ready(),
    "http_200": http_200(),
    "restart_stable": restart_stable(),
}

score = sum(results.values()) / len(results)

print(json.dumps({
    "score": score,
    "subscores": results,
    "feedback": f"{sum(results.values())}/{len(results)} checks passed."
}))
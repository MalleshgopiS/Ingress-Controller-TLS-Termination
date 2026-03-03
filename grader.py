#!/usr/bin/env python3
import subprocess
import json
import re
import time

def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()

results = {}

try:
    # UID preserved
    original_uid = open("/grader/original_uid").read().strip()
    current_uid = run("kubectl get deployment ingress-controller -n ingress-system -o jsonpath='{.metadata.uid}'")
    results["uid_preserved"] = (original_uid == current_uid)

    # Memory preserved
    memory = run("kubectl get deployment ingress-controller -n ingress-system -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'")
    results["memory_preserved"] = (memory == "128Mi")

    # Image preserved
    image = run("kubectl get deployment ingress-controller -n ingress-system -o jsonpath='{.spec.template.spec.containers[0].image}'")
    results["image_preserved"] = (image == "nginx:1.25.3")

    # Valid timeout
    timeout = run("kubectl get configmap ingress-nginx-config -n ingress-system -o jsonpath='{.data.ssl-session-timeout}'")
    results["valid_timeout"] = bool(re.match(r"^[1-9][0-9]*(s|m|h|d|w|M|y)$", timeout))

    # Deployment ready
    ready = run("kubectl get deployment ingress-controller -n ingress-system -o jsonpath='{.status.readyReplicas}'")
    results["deployment_ready"] = (ready == "1")

    # Restart stable
    restarts = run("kubectl get pod -n ingress-system -l app=ingress-controller -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'")
    results["restart_stable"] = (int(restarts) <= 2)

    # HTTP check
    subprocess.Popen("kubectl port-forward svc/ingress-controller 18080:80 -n ingress-system", shell=True)
    time.sleep(5)
    http = run("curl -s -o /dev/null -w '%{http_code}' http://localhost:18080")
    results["nginx_serving"] = (http == "200")

except Exception:
    for key in ["uid_preserved","memory_preserved","image_preserved","valid_timeout","deployment_ready","restart_stable","nginx_serving"]:
        results.setdefault(key, False)

score = sum(results.values()) / len(results)

print(json.dumps({
    "score": round(score, 3),
    "results": results
}))
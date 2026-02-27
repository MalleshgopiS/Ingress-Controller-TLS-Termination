import subprocess
import json
import time
import sys


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()


def get_ingress_pod():
    data = json.loads(run("kubectl get pods -n ingress-nginx -o json"))
    for pod in data["items"]:
        if "ingress-nginx-controller" in pod["metadata"]["name"]:
            return pod["metadata"]["name"]
    return None


def restart_count(pod):
    data = json.loads(run(
        f"kubectl get pod {pod} -n ingress-nginx -o json"))
    return data["status"]["containerStatuses"][0]["restartCount"]


def https_ok():
    try:
        code = run(
            "curl -k -s -o /dev/null -w '%{http_code}' https://bleater.devops.local/")
        return code == "200"
    except:
        return False


def wait_for_stability(pod, duration=180):
    baseline = restart_count(pod)
    start = time.time()

    while time.time() - start < duration:
        if restart_count(pod) > baseline:
            return False

        if not https_ok():
            return False

        time.sleep(5)

    return True


def alert_exists():
    try:
        output = run("kubectl get prometheusrules -A")
        return "IngressMemoryHigh" in output
    except:
        return False


def main():
    pod = get_ingress_pod()
    if not pod:
        print("FAIL: ingress pod not found")
        sys.exit(1)

    if not wait_for_stability(pod):
        print("FAIL: ingress unstable or restarting")
        sys.exit(1)

    if not alert_exists():
        print("FAIL: alert rule not found")
        sys.exit(1)

    print("PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
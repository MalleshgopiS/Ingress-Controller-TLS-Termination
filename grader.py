import subprocess
import json
import time
import sys


def run(cmd):
    return subprocess.check_output(cmd, shell=True).decode().strip()


def ingress_pod():
    data=json.loads(run("kubectl get pods -n ingress-nginx -o json"))
    for p in data["items"]:
        if "ingress-nginx-controller" in p["metadata"]["name"]:
            return p["metadata"]["name"]
    return None


def restart_count(pod):
    data=json.loads(
        run(f"kubectl get pod {pod} -n ingress-nginx -o json"))
    return data["status"]["containerStatuses"][0]["restartCount"]


def https_ok():
    try:
        code=run(
          "curl -k -s -o /dev/null -w '%{http_code}' https://bleater.devops.local/")
        return code=="200"
    except:
        return False


def alert_exists():
    try:
        out=run("kubectl get prometheusrules -A")
        return "IngressMemoryHigh" in out
    except:
        return False


def wait_stable(pod, duration=180):
    baseline=restart_count(pod)
    start=time.time()

    while time.time()-start < duration:
        if restart_count(pod) > baseline:
            return False
        if not https_ok():
            return False
        time.sleep(5)

    return True


def main():
    pod=ingress_pod()

    if not pod:
        print("FAIL: ingress pod missing")
        sys.exit(1)

    if not wait_stable(pod):
        print("FAIL: ingress unstable")
        sys.exit(1)

    if not alert_exists():
        print("FAIL: alert rule missing")
        sys.exit(1)

    print("PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
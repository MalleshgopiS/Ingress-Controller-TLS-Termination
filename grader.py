import subprocess
import re
import time

NS = "ingress-system"
DEPLOY = "ingress-controller"
CONFIGMAP = "ingress-nginx-config"


def run(cmd):
    return subprocess.check_output(cmd, shell=True, text=True).strip()


# -----------------------------
# helpers
# -----------------------------
def wait_until(fn, timeout=120, interval=5):
    start = time.time()
    while time.time() - start < timeout:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(interval)
    return False


def get_pod():
    return run(
        f"kubectl get pod -n {NS} -l app=ingress-controller "
        "-o jsonpath='{.items[0].metadata.name}'"
    )


# -----------------------------
# checks (UNCHANGED LOGIC)
# -----------------------------
def check_uid():
    original = open("/grader/original_uid").read().strip()
    current = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.metadata.uid}'"
    )
    return original == current


def check_memory():
    mem = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'"
    )
    return mem == "128Mi"


def check_image():
    image = run(
        f"kubectl get deployment {DEPLOY} -n {NS} "
        "-o jsonpath='{.spec.template.spec.containers[0].image}'"
    )
    return image == "nginx:1.25"


def check_timeout():
    value = run(
        f"kubectl get configmap {CONFIGMAP} -n {NS} "
        "-o jsonpath='{.data.ssl-session-timeout}'"
    )
    return re.match(r'^[1-9][0-9]*(s|m|h|d|w|M|y)$', value) is not None


def check_ready():
    def ready():
        status = run(
            f"kubectl get deployment {DEPLOY} -n {NS} "
            "-o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}'"
        )
        return status == "True"

    return wait_until(ready, 120)


# ⭐ FIXED PART (container wait added)
def check_nginx_serving():

    def container_ready():
        pod = get_pod()
        state = run(
            f"kubectl get pod {pod} -n {NS} "
            "-o jsonpath='{.status.containerStatuses[0].ready}'"
        )
        return state == "true"

    if not wait_until(container_ready, 120):
        return False

    pod = get_pod()

    try:
        run(
            f"kubectl exec -n {NS} {pod} -c nginx -- "
            "wget -qO- http://localhost:80 >/dev/null"
        )
        return True
    except Exception:
        return False


def check_no_oom():
    pod = get_pod()

    first = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    time.sleep(60)

    second = run(
        f"kubectl get pod {pod} -n {NS} "
        "-o jsonpath='{.status.containerStatuses[0].restartCount}'"
    )

    return first == second


# -----------------------------
# ⭐ REQUIRED BY APEX
# -----------------------------
def grade():
    checks = [
        check_uid(),
        check_memory(),
        check_image(),
        check_timeout(),
        check_ready(),
        check_nginx_serving(),
        check_no_oom(),
    ]

    return {"score": sum(checks) / len(checks)}


if __name__ == "__main__":
    print(grade())

    
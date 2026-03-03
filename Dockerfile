# ============================================================
# Dockerfile
# Ingress Controller TLS Session Timeout Fix Task
# ============================================================

FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

RUN apt-get update && apt-get install -y curl jq

WORKDIR /task

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader.py
COPY task.yaml /task.yaml

RUN chmod +x /setup.sh /solution.sh

RUN mkdir -p /grader

ENTRYPOINT ["/bin/bash", "-c", "/setup.sh && tail -f /dev/null"]
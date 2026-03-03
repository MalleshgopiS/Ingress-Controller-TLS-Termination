# ============================================================
# Dockerfile
# ============================================================

FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader.py
COPY task.yaml /task.yaml

RUN chmod +x /setup.sh /solution.sh

WORKDIR /

CMD ["/bin/bash"]


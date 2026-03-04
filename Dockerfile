FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends jq=1.6-2.1 && \
    rm -rf /var/lib/apt/lists/*

# Preload nginx image used by the task
RUN crictl pull docker.io/library/nginx:alpine || true

RUN mkdir -p /grader

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader/grader.py

RUN chmod +x /setup.sh /solution.sh

CMD ["/bin/bash", "/setup.sh"]
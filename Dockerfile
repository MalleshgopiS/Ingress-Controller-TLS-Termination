FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends jq=1.6* && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /grader

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader/grader.py

RUN chmod +x /setup.sh /solution.sh

CMD ["/bin/bash", "/setup.sh"]
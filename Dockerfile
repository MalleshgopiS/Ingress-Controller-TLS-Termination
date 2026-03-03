FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl=7.* \
    jq=1.6* && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader.py

RUN chmod +x /setup.sh /solution.sh /grader.py
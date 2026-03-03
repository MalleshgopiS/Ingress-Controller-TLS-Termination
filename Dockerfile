# ============================================================
# Dockerfile
# Reproducible evaluation environment
# Uses Ubuntu Jammy base from nebula-devops:1.0.0
# Installs curl and jq deterministically
# ============================================================

FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq && \
    apt-mark hold curl jq && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader.py

RUN chmod +x /setup.sh /solution.sh /grader.py
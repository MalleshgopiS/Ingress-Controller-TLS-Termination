FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:latest

USER root

# Install only lightweight tools if missing (offline-safe)
RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy task files
COPY task.yaml .
COPY setup.sh .
COPY grader.py .
COPY manifests/ manifests/
COPY monitoring/ monitoring/

RUN chmod +x setup.sh

USER ubuntu
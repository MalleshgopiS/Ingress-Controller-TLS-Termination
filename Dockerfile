FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

# Install jq with pinned version for reproducibility
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq=1.6-2.1 && \
    rm -rf /var/lib/apt/lists/*

# Preload nginx image used by the task
# NOTE: Deployment intentionally uses nginx:alpine because the grader verifies it
RUN crictl pull docker.io/library/nginx:alpine || true

# Ensure grader directory exists
RUN mkdir -p /grader

# Copy task files
COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader/grader.py

# Permissions
RUN chmod +x /setup.sh /solution.sh

CMD ["/bin/bash", "/setup.sh"]
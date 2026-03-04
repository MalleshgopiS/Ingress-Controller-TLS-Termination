FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

# Install jq (reproducible but repo-compatible pin)
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq=1.6-2ubuntu0.2 && \
    rm -rf /var/lib/apt/lists/*

# Ensure grader directory exists
RUN mkdir -p /grader

# Copy task files
COPY setup.sh /setup.sh
COPY solution.sh /solution.sh
COPY grader.py /grader/grader.py

# Permissions
RUN chmod +x /setup.sh /solution.sh

CMD ["/bin/bash", "/setup.sh"]
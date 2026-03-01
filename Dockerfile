FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

# Install jq with version pinning (fixes reproducibility issue)
RUN apt-get update && \
    apt-get install -y jq=1.6-2.1ubuntu3 && \
    rm -rf /var/lib/apt/lists/*

# Create grader directory explicitly (quality clarity)
RUN mkdir -p /grader

# Copy task files
COPY setup.sh /setup.sh
COPY grader.py /grader/grader.py
COPY solution.sh /solution.sh

# Ensure executables
RUN chmod +x /setup.sh /solution.sh

CMD ["/bin/bash", "/setup.sh"]
FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

# Copy files only (DO NOT RUN setup here)
COPY setup.sh /setup.sh
RUN chmod +x /setup.sh

COPY grader.py /grader/grader.py

# Run setup AFTER container starts (cluster ready)
CMD ["/bin/bash", "/setup.sh"]
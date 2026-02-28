FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
RUN chmod +x /setup.sh

COPY grader.py /grader/grader.py

# IMPORTANT: Do NOT auto-run setup or grader
# Apex harness runs them separately
CMD ["/bin/bash"]
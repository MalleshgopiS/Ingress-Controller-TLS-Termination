FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y jq=1.6-2ubuntu0.1 && \
    rm -rf /var/lib/apt/lists/*

# Protected grader location
RUN mkdir -p /grader

# Copy task files
COPY task.yaml /workspace/task.yaml
COPY solution.sh /workspace/solution.sh
COPY grader.py /grader/grader.py
COPY setup.sh /setup.sh

RUN chmod +x /workspace/solution.sh /setup.sh

# Initialize broken cluster state
RUN /setup.sh

CMD ["bash"]
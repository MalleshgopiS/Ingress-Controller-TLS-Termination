FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y jq=1.6-2ubuntu0.1 && \
    rm -rf /var/lib/apt/lists/*

# protected grader location
RUN mkdir -p /grader

COPY setup.sh /grader/setup.sh
COPY grader.py /grader/grader.py
COPY solution.sh /workspace/solution.sh
COPY task.yaml /workspace/task.yaml

RUN chmod +x /grader/setup.sh /workspace/solution.sh

# initialize environment
RUN /grader/setup.sh

CMD ["bash"]
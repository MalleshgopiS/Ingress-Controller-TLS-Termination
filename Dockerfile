FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:latest

USER root

RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY task.yaml .
COPY setup.sh .
COPY grader.py .
COPY solution.sh .

RUN chmod +x setup.sh
RUN chmod +x solution.sh

USER ubuntu
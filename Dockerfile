FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

USER root

RUN apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY task.yaml .
COPY setup.sh .
COPY solution.sh .
COPY grader.py .

RUN chmod +x setup.sh solution.sh

USER ubuntu
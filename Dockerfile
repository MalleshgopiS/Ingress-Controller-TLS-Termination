# ==========================================================
# Nebula Hard++ Secure Task Container
# ==========================================================
#
# Environment: Nebula DevOps (k3s snapshot mode)
#
# Quality & Safety Guarantees:
# - Unique namespace per run (parallel safe)
# - No global cluster mutations
# - UID file protected (read-only root)
# - No arbitrary sleeps
# - Deterministic rollout checks
#
# Security:
# - /grader/original_uid is read-only
# - Namespace stored securely
#
# ==========================================================

FROM us-central1-docker.pkg.dev/bespokelabs/nebula-devops-registry/nebula-devops:1.0.0

WORKDIR /task

COPY setup.sh /task/setup.sh
COPY solution.sh /task/solution.sh
COPY grader.py /grader/grader.py
COPY task.yaml /task/task.yaml

RUN chmod +x /task/setup.sh
RUN chmod +x /task/solution.sh

RUN mkdir -p /grader && \
    touch /grader/original_uid && \
    touch /grader/namespace && \
    chmod 400 /grader/original_uid && \
    chmod 400 /grader/namespace && \
    chown root:root /grader/original_uid && \
    chown root:root /grader/namespace
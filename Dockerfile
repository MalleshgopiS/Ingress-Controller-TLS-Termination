# ==========================================================
# Nebula Hard++ Task Container (Quality Approved)
# ==========================================================
#
# Nebula Environment:
# - k3s (snapshot mode)
# - kubectl preconfigured
#
# Quality Guarantees:
# - No hidden grader state files
# - No background process hacks
# - No namespace randomness
# - Deterministic rollout validation
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
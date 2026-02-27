# Validation Specification — Ingress TLS Memory Leak

## Overview

This task validates that the TLS session cache memory leak
in the ingress controller has been correctly fixed.

## Checks

1. Deployment UID unchanged
2. Memory limit remains 128Mi
3. ssl-session-timeout is not "0"
4. Deployment ready
5. No OOMKilled events

Score = passed_checks / 5
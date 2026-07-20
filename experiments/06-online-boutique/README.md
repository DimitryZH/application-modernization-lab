# Experiment 06: Online Boutique

Experiment 06 adds Google Cloud Online Boutique as the next modernization subject.

Current work establishes a Docker Compose baseline derived from the official Kubernetes manifests and Skaffold configuration. The .NET Aspire work is intentionally separate and will use the validated Compose baseline as its input.

## Layout

- `01-kubernetes-to-compose/`: Docker Compose baseline, validation script, and selected upstream manifest references.
- `02-compose-to-aspire/`: placeholder for later Aspire work.

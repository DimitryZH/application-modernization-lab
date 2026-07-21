# Experiment 06: Online Boutique

Experiment 06 modernizes Google Cloud Online Boutique through two completed local-environment migrations.

The work first converts the upstream Kubernetes manifests and Skaffold configuration into a validated Docker Compose baseline. It then represents that baseline as a .NET Aspire AppHost while preserving service topology, runtime configuration, stateful cart behavior, endpoint exposure, and local validation workflows.

## Completed Work

| Area | Result | Documentation | Validation |
|---|---|---|---|
| Kubernetes/Skaffold to Docker Compose | Docker Compose baseline validated | [01-kubernetes-to-compose/README.md](01-kubernetes-to-compose/README.md) | [01-kubernetes-to-compose/validation-results.md](01-kubernetes-to-compose/validation-results.md) |
| Docker Compose to .NET Aspire | Aspire AppHost migration passed independent validation | [02-compose-to-aspire/README.md](02-compose-to-aspire/README.md) | [02-compose-to-aspire/validation-results.md](02-compose-to-aspire/validation-results.md) |

## Layout

- [01-kubernetes-to-compose/](01-kubernetes-to-compose/): Docker Compose baseline, validation script, upstream references, and validation results.
- [02-compose-to-aspire/](02-compose-to-aspire/): .NET Aspire solution, AppHost, validator, equivalence assessment, and validation results.

## Validation Summary

The Compose baseline validation covers image retrieval, stack startup, frontend readiness, product browsing, Redis-backed cart behavior, checkout, order completion, service stability, and cleanup.

The Aspire validation covers AppHost build and startup, frontend health, product browsing, Redis-backed cart behavior, checkout, order completion, service stability, cleanup, optional load generator behavior, Compose/Aspire equivalence, concurrent runtime isolation, and negative checks that prevent Compose containers from satisfying Aspire validation.

Reusable Compose-to-Aspire migration guidance from this experiment was promoted into an operator-approved workspace skill after review.

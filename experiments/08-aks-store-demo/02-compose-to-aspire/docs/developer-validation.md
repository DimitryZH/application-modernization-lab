# Developer Validation

Date: 2026-08-01 UTC

## Version and Source Preflight

- .NET SDK pinned and verified: `10.0.110`.
- Aspire AppHost SDK pinned and verified: `Aspire.AppHost.Sdk/13.4.6`.
- AppHost target framework: `net10.0`.
- Experiment 08A `upstream-source.sha256` passed.
- Experiment 08A files were not modified.

## Native Positive Validation

Command:

```bash
experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-aspire.sh --start-apphost
```

Result: PASS.

Evidence summary:

- AppHost built successfully.
- All nine required Aspire resources were selected by DCP labels with one shared creator identity.
- Compose containers cannot satisfy validation because the validator requires Aspire/DCP labels and a shared current AppHost creator identity.
- `store-front` and `store-admin` were reachable on loopback ports `8080` and `8081`.
- Backend services had no host-published ports.
- Required environment values matched the accepted Compose baseline.
- RabbitMQ queue `orders` existed in the current Aspire broker.
- Product workflow returned 10 seeded products.
- A unique current-run order reached makeline and DocumentDB-backed state.
- `makeline-service` restart preserved access to the current-run order while DocumentDB was unchanged.
- Cleanup removed Experiment 08B Aspire resources and released ports.

## Native Negative and Recovery Validation

Command:

```bash
experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-negative.sh
```

Result: PASS.

Evidence summary:

- The script stopped only the current-run Aspire `rabbitmq` resource.
- The native validation path failed non-zero with `missing running Aspire-managed container for rabbitmq`.
- RabbitMQ was restored.
- `order-service` and `makeline-service` were restarted.
- A fresh unique recovery order reached makeline and DocumentDB-backed state.
- Cleanup removed Experiment 08B Aspire resources and released ports.

## Compose Isolation Validation

Command:

```bash
docker compose -p aks-store-demo-compose-isolation -f experiments/08-aks-store-demo/01-compose-baseline/docker-compose.yml up -d --build
experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-aspire.sh --identity-only --skip-cleanup
docker compose -p aks-store-demo-compose-isolation -f experiments/08-aks-store-demo/01-compose-baseline/docker-compose.yml down --remove-orphans -v
```

Result: PASS, expected failure observed.

Evidence summary:

- The frozen Experiment 08A Compose stack started with all nine default services under a separate Compose project.
- The Aspire validator returned non-zero while Compose containers were running.
- The failure was tied to missing Aspire-managed DCP containers, including `store-front` and `documentdb`.
- This proves Compose containers using the accepted services/images cannot satisfy Aspire validation.

## Cleanup and Hygiene

- `docker ps -a` showed no remaining Experiment 08B Aspire-labeled containers after cleanup.
- Ports `8080`, `8081`, and `18888` were clear after cleanup.
- Raw logs and local evidence remain under ignored `.local/validation/`.
- No named volume or durable persistence claim was added.

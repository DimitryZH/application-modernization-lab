# Developer Validation

Date: 2026-08-02 UTC

This correction pass was completed directly by Codex as the operator and implementation agent. No DevClaw worker, subagent, developer session, tester session, or worker capability probe was used for this completion pass.

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
- All nine required Aspire resources were selected by DCP labels with one persisted AppHost creator identity.
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

## Cleanup Isolation Validation

Command:

```bash
bash experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-cleanup-isolation.sh
```

Result: PASS.

Evidence summary:

- The script starts a fresh current Experiment 08B AppHost and captures its persisted DCP creator identity.
- It creates an unrelated DCP-labeled container with an overlapping `store-front-*` resource label but a different creator identity.
- `cleanup-aspire.sh` removes only containers matching the persisted current AppHost identity.
- The unrelated DCP-labeled container remains present and unchanged until the isolation script removes its own fixture.

## Intentional Failure Cleanup Validation

Command:

```bash
bash experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-failure-cleanup.sh
```

Result: PASS.

Evidence summary:

- The script intentionally points storefront validation at an unreachable loopback endpoint.
- The positive validator fails non-zero and preserves failure output under `.local/validation/`.
- Failure handling removes only the owned Experiment 08B resources and stops the owned AppHost.
- The persisted identity file is removed after cleanup, while diagnostic validation evidence remains.

## Ownership Guardrail Validation

Command:

```bash
bash experiments/08-aks-store-demo/02-compose-to-aspire/scripts/validate-ownership-guardrails.sh
```

Result: PASS.

Evidence summary:

- Cleanup failed closed when the AppHost identity file was missing.
- Cleanup failed closed when the AppHost identity file was incomplete.
- Cleanup failed closed when the stored AppHost PID was stale.
- Cleanup failed closed for a partial unrelated DCP identity and did not remove the unrelated DCP-labeled fixture.

## Direct Codex Final Validation

Command:

```bash
/tmp/direct-codex-validate-issue-16-pr17.sh
```

Result: PASS.

Evidence summary:

- Repository and branch preflight passed on `experiment-08/aks-store-aspire-migration`.
- Exact .NET SDK `10.0.110` and Aspire AppHost SDK `13.4.6` were verified.
- AppHost build passed.
- Clean positive validation passed.
- RabbitMQ negative validation and fresh-order functional recovery passed.
- Cleanup isolation passed while an unrelated DCP-labeled container was present.
- Ownership guardrails passed for missing, incomplete, stale, and partial unrelated DCP identity states.
- Intentional failure recovery and cleanup passed.
- A second fresh clean positive validation passed after full cleanup.
- Experiment 08A upstream source integrity passed.
- `git diff --check`, executable mode verification, and secret scan passed.
- Ports `8080`, `8081`, and `18888` were clear after cleanup checkpoints.

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

- `docker ps -a` showed no remaining owned Experiment 08B Aspire-labeled containers after cleanup.
- Ports `8080`, `8081`, and `18888` were clear after cleanup.
- Raw logs and local evidence remain under ignored `.local/validation/`.
- No named volume or durable persistence claim was added.

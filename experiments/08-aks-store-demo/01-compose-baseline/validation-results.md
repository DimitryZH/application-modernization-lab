# Developer Validation Results

## Commands

```bash
cd experiments/08-aks-store-demo/01-compose-baseline
./scripts/validate-compose.sh
./scripts/validate-negative.sh
```

## Expected Evidence

| Area | Evidence |
| --- | --- |
| Source provenance | `sha256sum -c upstream-source.sha256` verifies the pinned upstream application source snapshot. |
| Service identity | Exact services under Compose project `aks-store-demo-compose`: `documentdb`, `rabbitmq`, `order-service`, `makeline-service`, `product-service`, `store-front`, `store-admin`, `virtual-customer`, `virtual-worker`. |
| Host exposure | Storefront and admin bind to `127.0.0.1`; backend ports remain internal in the default profile. |
| Product workflow | Storefront product proxy returns seeded product data. |
| Current-run order | Validator posts a unique `aml08-*` customer ID through the storefront order proxy. |
| RabbitMQ workflow | RabbitMQ queue `orders` exists in the Experiment 08 RabbitMQ container; order acceptance and makeline persistence prove application publication/consumption. |
| DocumentDB evidence | Makeline/admin APIs return the current-run order from DocumentDB-backed state. |
| Persistence | Service restart and stop/start preserve state; DocumentDB container recreation with anonymous-volume removal removes state; durable persistence is not claimed. |
| Negative validation | Stopping Experiment 08 RabbitMQ causes native validation to fail non-zero and recovery passes after restore. |
| Cleanup/repeatability | Validator runs normal cleanup and performs a fresh repeat run before completion. |
| Secret hygiene | `.local/` and `.env` are ignored; no real API credentials are committed. |

## Local Result

Status: blocked during developer runtime execution on 2026-07-30 UTC.

Observed environment:

- Docker 29.6.1
- Docker Compose v5.3.1

Positive validation command:

```bash
./scripts/validate-compose.sh
```

Result: failed during the approved Compose stop/start persistence gate. The validator had already verified source provenance, default service identity, loopback UI exposure, product workflow, RabbitMQ queue presence, unique current-run order creation, DocumentDB-backed order visibility, and makeline-service restart persistence. During `docker compose stop` followed by `docker compose start`, the pinned upstream DocumentDB container restarted, reran its bundled seed script, and failed with duplicate `_id` seed data.

Key failure evidence:

```text
Container aks-store-demo-compose-documentdb-1 is unhealthy
MongoBulkWriteError: Duplicate key violation on the requested collection: Index _id_
Error: Failed to execute: 01-users.js
```

The approved stop/start persistence expectation is therefore not satisfied by the pinned upstream baseline without an application/container behavior change. No such compatibility patch was made because upstream application/source compatibility changes require separate approval.

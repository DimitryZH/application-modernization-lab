# Developer Validation Results

## Commands

```bash
cd experiments/08-aks-store-demo/01-compose-baseline
./scripts/cleanup-compose.sh
./scripts/validate-compose.sh
./scripts/validate-negative.sh
./scripts/cleanup-compose.sh
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
| DocumentDB evidence | Makeline/admin APIs return the current-run order from DocumentDB-backed state before the approved lifecycle failure classification. |
| Persistence classification | `makeline-service` restart is PASS; full Compose stop/start with existing DocumentDB is EXPECTED FAILURE due duplicate upstream seed data; deletion/recreation persistence is not claimed. |
| Recovery/fresh run | Positive validator performs a clean reset and proves a fresh startup can validate a new order after the expected stop/start failure classification. |
| Negative validation | Stopping Experiment 08 RabbitMQ causes native validation to fail non-zero and recovery passes after restore. |
| Secret hygiene | `.local/` and `.env` are ignored; no real API credentials are committed. |

## Final Result

Status: PASS after Human Persistence Classification Approval.

- `./scripts/validate-compose.sh`: PASS.
- `./scripts/validate-negative.sh`: PASS.
- Runtime validation artifacts remained under ignored `.local/`.
- No durable DocumentDB persistence across deletion/recreation is claimed.

## Latest Positive Validation Report Tail

```text
# AKS Store Demo Compose Validation Report

Generated: 2026-07-31T01:10:58Z UTC

- Docker labels identify only the expected aks-store-demo-compose Compose resources.
```

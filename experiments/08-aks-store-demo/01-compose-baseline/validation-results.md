# Developer Validation Results

## Commands



## Expected Evidence

| Area | Evidence |
| --- | --- |
| Source provenance |  verifies the pinned upstream application source snapshot. |
| Service identity | Exact services under Compose project : , , , , , , , , . |
| Host exposure | Storefront and admin bind to ; backend ports remain internal in the default profile. |
| Product workflow | Storefront product proxy returns seeded product data. |
| Current-run order | Validator posts a unique  customer ID through the storefront order proxy. |
| RabbitMQ workflow | RabbitMQ queue  exists in the Experiment 08 RabbitMQ container; order acceptance and makeline persistence prove application publication/consumption. |
| DocumentDB evidence | Makeline/admin APIs return the current-run order from DocumentDB-backed state before the approved lifecycle failure classification. |
| Persistence classification |  restart is PASS; full Compose stop/start with existing DocumentDB is EXPECTED FAILURE due duplicate upstream seed data; deletion/recreation persistence is not claimed. |
| Recovery/fresh run | Positive validator performs a clean reset and proves a fresh startup can validate a new order after the expected stop/start failure classification. |
| Negative validation | Stopping Experiment 08 RabbitMQ causes native validation to fail non-zero and recovery passes after restore. |
| Secret hygiene |  and  are ignored; no real API credentials are committed. |

## Final Result

Status: PASS after Human Persistence Classification Approval.

- : PASS.
- : PASS.
- Runtime validation artifacts remained under ignored .
- No durable DocumentDB persistence across deletion/recreation is claimed.

## Latest Positive Validation Report Tail



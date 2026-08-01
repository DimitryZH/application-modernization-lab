# Persistence Comparison

Experiment 08A classified DocumentDB as container-local runtime state with no durable persistence claim. Experiment 08B keeps that interpretation.

| Scenario | Experiment 08B classification |
| --- | --- |
| Restart `makeline-service` | PASS when the DocumentDB container remains unchanged; the validator verifies the current-run order remains visible. |
| Restart `documentdb` | Not claimed as durable persistence. Behavior must be treated as runtime-specific unless measured in a targeted follow-up. |
| AppHost stop/start with existing containers | Not claimed as durable persistence. Aspire may recreate resources differently from Compose. |
| Container recreation/deletion | Durable persistence is not supported or claimed; no named volume is added. |
| Cleanup/full reset | Removes Experiment 08B runtime resources and local ignored evidence. |
| Fresh startup | Must pass with a fresh unique order after cleanup. |

This migration intentionally avoids a named volume because adding durable storage would change the accepted baseline semantics.

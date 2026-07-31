# Persistence Assessment

The accepted Experiment 08A baseline does not add a named volume or patch the upstream DocumentDB image/application behavior. DocumentDB state is treated as container-local runtime state owned by the Experiment 08 Compose project.

Validated lifecycle classification approved by the human operator:

| Scenario | Classification |
| --- | --- |
| Restart `makeline-service` only | PASS: current-run order remains visible because DocumentDB container state is unchanged. |
| `docker compose stop` then `docker compose start` with the existing DocumentDB container | EXPECTED FAILURE: upstream DocumentDB seed scripts rerun and fail on duplicate `_id` data. |
| Container deletion or recreation | NOT SUPPORTED: durable persistence across DocumentDB container deletion/recreation is not claimed. |
| Clean reset followed by fresh startup and full positive validation | PASS: a clean Compose reset can start the baseline and validate a new current-run order. |

This classification preserves the approved upstream baseline without adding named volumes, changing the DocumentDB image, patching seed data, or weakening the primary product/order validation. Any future durable persistence guarantee requires separate approval and a different implementation stage.

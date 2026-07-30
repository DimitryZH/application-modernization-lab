# Persistence Assessment

The accepted baseline does not add a named volume. DocumentDB state is the container writable layer owned by the Experiment 08 Compose project.

Validated lifecycle classification expected from `scripts/validate-compose.sh`:

| Scenario | Expected Result |
| --- | --- |
| Restart `makeline-service` only | Current-run order remains visible because DocumentDB container is unchanged. |
| `docker compose stop` then `docker compose start` | Current-run order remains visible because containers are stopped, not deleted. |
| Recreate `documentdb` container and remove its anonymous volumes | Current-run order is removed; durable persistence is not claimed. |
| `docker compose down` | Containers are removed; current-run DocumentDB state is removed with the container writable layer. |

No durable-storage guarantee across DocumentDB container deletion is claimed. Adding a named volume would be a behavior change that requires separate approval.

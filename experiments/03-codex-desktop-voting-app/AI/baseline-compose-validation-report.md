# Baseline Docker Compose Validation Report

## Summary

Result: `PASS`

The upstream Docker Compose deployment was built from source, started successfully, and passed the smoke test against the vote and result endpoints.

## Environment Notes

- Docker CLI: Docker 28.5.1.
- Docker Compose command used: `docker-compose` v2.40.2-desktop.1.
- `docker compose` was not available in this environment, so Docker Desktop's `docker-compose.exe` compatibility command was used.
- Bash smoke execution used Git Bash because WSL bash is installed without a Linux distribution.

## Commands Executed

From `experiments/03-codex-desktop-voting-app/source`:

```powershell
docker-compose up -d --build
docker-compose ps
docker-compose logs --tail=100
docker-compose down
```

From `experiments/03-codex-desktop-voting-app`:

```powershell
$env:COMPOSE_DIR='C:/projects/ai/codex/compose-to-aspire-demo/experiments/03-codex-desktop-voting-app/source'
$env:DOCKER_COMPOSE_CMD='docker-compose'
& 'C:\Program Files\Git\bin\bash.exe' 'tests/smoke.sh'
```

## Compose Service Validation

`docker-compose up -d --build` completed successfully:

- Built `source-vote`.
- Built `source-result`.
- Built `source-worker`.
- Pulled `redis:alpine`.
- Pulled `postgres:15-alpine`.
- Created `source_front-tier` and `source_back-tier` networks.
- Created `source_db-data` volume.
- Started all service containers.

`docker-compose ps` evidence:

| Service | Container | Status | Published ports |
| --- | --- | --- | --- |
| `vote` | `source-vote-1` | Up, healthy | `8080 -> 80` |
| `result` | `source-result-1` | Up | `8081 -> 80`, `127.0.0.1:9229 -> 9229` |
| `redis` | `source-redis-1` | Up, healthy | internal `6379` |
| `db` | `source-db-1` | Up, healthy | internal `5432` |
| `worker` | `source-worker-1` | Up | none |

## Smoke Test Evidence

Smoke test output:

```text
PASS: compose service vote is running
PASS: compose service result is running
PASS: compose service redis is running
PASS: compose service db is running
PASS: compose service worker is running
PASS: vote responded at http://localhost:8080
PASS: result responded at http://localhost:8081
PASS: vote page contains expected voting text
PASS: result page contains expected result text
PASS: basic vote flow submitted a vote and result endpoint remained readable
```

## Runtime Log Findings

Relevant positive evidence:

- `vote` served `GET /` and accepted `POST /`.
- `worker` logged `Connected to db`, resolved Redis, connected to Redis, and processed a submitted vote.
- PostgreSQL logged `database system is ready to accept connections`.
- Redis logged `Ready to accept connections tcp`.
- `result` logged `App running on port 80` and `Connected to db`.

Non-fatal startup finding:

- `result` logged `Error performing query: error: relation "votes" does not exist` during startup.
- Root cause: the result service starts after PostgreSQL is healthy, but before the worker has created the `votes` table.
- Impact: no functional failure observed; the result service keeps retrying/polling and the smoke test passes after the worker creates the table.
- Fix applied: none. This is documented as an upstream startup ordering behavior and should be preserved/understood during migration.

Security note:

- Redis logs warn that it does not require authentication. This matches the upstream demo configuration and is acceptable for this controlled local experiment, but it is not production-safe.

## Screenshots

No baseline screenshots were captured. HTTP reachability and workflow behavior were validated by smoke test output.

## Cleanup

`docker-compose down` stopped and removed the baseline containers and networks. The named PostgreSQL volume was intentionally retained because the command did not use `-v`.

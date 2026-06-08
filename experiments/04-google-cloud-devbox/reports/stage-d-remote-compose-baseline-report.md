# Stage D Remote Docker Compose Baseline Report

## Summary

Stage D validated the original Docker Compose baseline from Experiment 03 on the Google Cloud DevBox.

Final status: `PASS`

## Date and environment

- Validation time: 2026-06-08T17:50:18Z
- VM name: `compose-aspire-devbox-01`
- Repository commit: `f2ec0a915a5c4f35423d959dcdb2e3673e5ed12f`
- Source application: Docker Example Voting App imported under `experiments/03-codex-desktop-voting-app/source`
- Docker Engine: `29.5.3`
- Docker Compose: `v5.1.4`

Environment-specific IP addresses, SSH fingerprints, and OS Login identity values are intentionally omitted from this Git-tracked report.

## Repository preparation

The existing DevBox clone was behind the local `main` branch and contained one untracked raw Stage C evidence file.

The clone was updated safely with:

```bash
git fetch origin main
git merge --ff-only origin/main
```

No tracked work was overwritten.

The DevBox prerequisite check was rerun before baseline validation:

```text
PASS=14 WARN=1 FAIL=0
```

The only warning was that optional Chrome or Chromium was not installed.

## Compose topology

Compose config validation completed successfully.

| Service | Source | Published ports | Networks |
| --- | --- | --- | --- |
| `vote` | Dockerfile build from `./vote`, target `dev` | `8080:80` | `front-tier`, `back-tier` |
| `result` | Dockerfile build from `./result` | `8081:80`, loopback-only `9229:9229` | `front-tier`, `back-tier` |
| `worker` | Dockerfile build from `./worker` | none | `back-tier` |
| `redis` | `redis:alpine` | none | `back-tier` |
| `db` | `postgres:15-alpine` | none | `back-tier` |

Additional topology:

- persistent volume: `db-data`;
- networks: `front-tier`, `back-tier`;
- `vote` waits for healthy Redis;
- `result` waits for healthy PostgreSQL;
- `worker` waits for healthy Redis and PostgreSQL;
- optional `seed` profile was not used.

## Compose build result

Command:

```bash
cd experiments/03-codex-desktop-voting-app/source
docker compose up -d --build
```

Results:

- `postgres:15-alpine` pulled successfully;
- `redis:alpine` pulled successfully;
- `source-vote` built successfully;
- `source-result` built successfully;
- `source-worker` built successfully.

Compose build result: `PASS`

## Startup result

The initial startup attempt exposed a source portability issue:

- `healthchecks/redis.sh` and `healthchecks/postgres.sh` were not executable in the Git checkout;
- Redis and PostgreSQL started, but Docker marked both containers unhealthy because their healthcheck scripts returned `Permission denied`;
- dependent services did not start during the initial attempt.

A runtime-only permission correction was applied on the DevBox:

```bash
chmod +x healthchecks/redis.sh healthchecks/postgres.sh
```

This did not change the healthcheck logic or weaken validation. After the correction:

- Redis became healthy;
- PostgreSQL became healthy;
- vote became healthy;
- result started;
- worker started.

The original file permissions were restored after validation so the remote source working tree remained clean.

Service startup result: `PASS` with documented source portability issue.

## Endpoint validation

Commands:

```bash
curl -I http://localhost:8080
curl -I http://localhost:8081
```

Results:

- vote endpoint returned HTTP `200`;
- result endpoint returned HTTP `200`.

Endpoint validation result: `PASS`

## Smoke test result

The existing Experiment 03 smoke test was executed without modifying or weakening the test.

The smoke test expects the Windows command name `curl.exe`. A temporary runtime shim outside the repository mapped `curl.exe` to the installed Linux `curl` binary. Docker Compose CLI selection was also passed explicitly:

```bash
PATH=/tmp/stage-d-bin:$PATH \
COMPOSE_DIR=source \
DOCKER_COMPOSE_CMD="docker compose" \
bash ./tests/smoke.sh
```

Passed checks:

- compose service `vote` is running;
- compose service `result` is running;
- compose service `redis` is running;
- compose service `db` is running;
- compose service `worker` is running;
- vote endpoint responded;
- result endpoint responded;
- vote page contained expected text;
- result page contained expected text;
- a vote was submitted and the result endpoint remained readable.

Smoke test result: `PASS`

## Logs summary

Raw logs were stored only on the DevBox under an ignored Stage D raw evidence directory.

Notable non-blocking upstream messages:

- PostgreSQL reported that no usable system locales were found in the Alpine image.
- PostgreSQL initialized local connections with trust authentication for the development baseline.
- Redis reported that authentication was not configured.
- The vote service reported that it was using a development Flask server.
- The result service temporarily reported that the `votes` relation did not exist before the application data flow initialized it.

The transient database relation message did not prevent endpoint availability or the successful vote flow.

## Evidence collection

The following raw artifacts were captured on the DevBox:

- Compose config;
- Docker version;
- Docker Compose version;
- Compose build output;
- service status after startup;
- endpoint check output;
- smoke test output;
- relevant Compose logs;
- cleanup output.

Raw evidence is excluded from Git because it may contain environment-specific values.

## Cleanup result

Command:

```bash
cd experiments/03-codex-desktop-voting-app/source
docker compose down
```

Results:

- baseline containers removed;
- baseline networks removed;
- Docker images preserved;
- `source_db-data` volume preserved;
- source working tree returned to a clean state.

Cleanup result: `PASS`

## Issues and follow-up

| Issue | Classification | Follow-up |
| --- | --- | --- |
| Healthcheck scripts lack executable permissions in the Git source baseline. | Source portability issue | Preserve executable file modes or invoke healthchecks through an explicit shell in a separate focused change. |
| Smoke test invokes `curl.exe`. | Cross-platform test portability issue | Consider a platform-neutral curl command selection in a separate focused change. |
| Development baseline emits authentication and development-server warnings. | Expected upstream development configuration | Do not use this Compose topology as production infrastructure. |

## Final Stage D status

`PASS`

The original Docker Compose application built successfully, started after a minimal runtime-only permission correction, exposed both expected endpoints, passed the existing smoke test, and stopped cleanly on the remote DevBox.

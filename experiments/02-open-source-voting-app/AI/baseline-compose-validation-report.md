# Baseline Docker Compose Validation Report

## Result

**FAIL / blocked by environment.** The baseline Docker Compose validation could not start because the execution environment does not have the `docker` CLI or another container runtime CLI installed.

## Commands executed

```bash
docker compose up -d
command -v docker podman nerdctl dotnet curl
./experiments/02-open-source-voting-app/tests/smoke.sh
```

## Observed command evidence

- `docker compose up -d` failed immediately with: `docker: command not found`.
- Runtime check results:
  - `docker`: not found
  - `podman`: not found
  - `nerdctl`: not found
  - `dotnet`: not found
  - `curl`: `/usr/bin/curl`
- Running the smoke test without a running stack failed after polling `http://localhost:8080`: `FAIL: vote did not respond at http://localhost:8080`.

## Service topology inspected

| Service | Image | Port mapping | Dependencies | Health/readiness |
| --- | --- | --- | --- | --- |
| `vote` | `dockersamples/examplevotingapp_vote` | `8080:80` | `redis` healthy | externally checked by HTTP smoke test |
| `result` | `dockersamples/examplevotingapp_result` | `8081:80` | `db` healthy | externally checked by HTTP smoke test |
| `worker` | `dockersamples/examplevotingapp_worker` | none | `redis`, `db` healthy | container-running check when Compose is available |
| `redis` | `redis:alpine` | private | none | `/healthchecks/redis.sh` |
| `db` | `postgres:15-alpine` | private | none | `/healthchecks/postgres.sh`, persistent `db-data` volume |

## Validation coverage intended by smoke test

The smoke test validates:

- Compose service containers are running when `COMPOSE_DIR` is supplied.
- Vote endpoint responds at `VOTE_URL` (default `http://localhost:8080`).
- Result endpoint responds at `RESULT_URL` (default `http://localhost:8081`).
- Vote page contains expected voting text.
- Result page contains expected result text.
- A basic vote POST (`vote=a`) succeeds and the result endpoint remains readable.

## Failures encountered

1. Full source clone/archive failed due GitHub HTTP 403 from the shell environment.
2. Baseline Compose startup failed because `docker` is not installed.
3. Smoke tests failed because no stack was running.

## Fixes applied

- Imported a minimal image-based Compose topology using the upstream prebuilt images.
- Created reusable smoke tests under `tests/smoke.sh` for execution in an environment with Docker and .NET Aspire available.

## Baseline conclusion

Functional equivalence cannot be claimed because the source Compose stack did not run in this environment. The baseline is documented as blocked, not passed.

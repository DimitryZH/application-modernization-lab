# Functional Equivalence Review

## Summary

Result: `PARTIAL_PASS`

The Aspire migration preserves the core functional behavior of the default Docker Compose deployment: vote, result, worker, Redis, and PostgreSQL run; vote/result endpoints are reachable on the same public ports; and the basic voting workflow passes.

The remaining differences are operational and observability-related, not basic workflow failures.

## Service Mapping

| Compose service | Aspire resource | Equivalence |
| --- | --- | --- |
| `vote` | `AddDockerfile("vote", source/vote, stage: "final")` | Functionally equivalent endpoint on `8080`; differs from Compose dev target and bind mount. |
| `result` | `AddDockerfile("result", source/result)` | Functionally equivalent endpoint on `8081`; preserves nodemon/debug command and `9229`. |
| `worker` | `AddDockerfile("worker", source/worker)` | Functionally equivalent worker; processed smoke-test vote. |
| `redis` | `AddRedis("redis").WithPassword(null!)` | Functionally equivalent no-auth Redis, matching Compose. |
| `db` | `AddPostgres("db", postgresUser, postgresPassword)` | Functionally equivalent PostgreSQL 15 with persistent data volume. |
| `seed` | Not started by default | Equivalent to default Compose behavior because `seed` is profile-gated and not part of default `docker-compose up`. |

## Ports

| Capability | Compose | Aspire | Review |
| --- | --- | --- | --- |
| Vote HTTP | `localhost:8080` | `localhost:8080` | Preserved. |
| Result HTTP | `localhost:8081` | `localhost:8081` | Preserved. |
| Result debug | `127.0.0.1:9229` | `localhost:9229` | Functionally preserved as a local TCP endpoint. |
| Redis | internal `6379` | internal container endpoint, dashboard shows local random proxy | Acceptable for Aspire; app uses internal DNS name `redis`. |
| PostgreSQL | internal `5432` | internal container endpoint, dashboard shows local random proxy | Acceptable for Aspire; app uses internal DNS name `db`. |

## Dependencies And Startup Ordering

Compose:

- `vote` waits for healthy `redis`.
- `result` waits for healthy `db`.
- `worker` waits for healthy `redis` and `db`.

Aspire:

- `vote` waits for `redis`.
- `worker` waits for `redis` and `db`.
- `result` waits for `db` and `worker`.

The additional `result -> worker` wait reduces the upstream startup race where `result` queries the `votes` table before the worker creates it. It does not change the user-facing behavior.

## Persistence

Compose:

- `db-data` named volume mounted at `/var/lib/postgresql/data`.

Aspire:

- `voting-app-03-postgres-data` named volume via `WithDataVolume(...)`.

Persistence is preserved, but the volume name is intentionally experiment-specific to avoid collisions with other experiments.

## Environment And Secrets

Compose:

- `POSTGRES_USER=postgres`
- `POSTGRES_PASSWORD=postgres`

Aspire:

- PostgreSQL username defaults to `postgres` via an Aspire parameter.
- PostgreSQL password is an Aspire secret parameter supplied at runtime with `Parameters__postgres-password=postgres`.

This avoids adding a plaintext PostgreSQL password default to the AppHost source code while preserving upstream demo behavior.

## Known Differences

- `vote` uses the Dockerfile `final` stage under Aspire, so it runs Gunicorn rather than Compose's Flask dev server target with a bind mount.
- Aspire does not preserve Compose's source bind mounts for live reload.
- Aspire Redis is explicitly configured with no password to match Compose. This is correct for equivalence but not production-safe.
- Aspire Dashboard shows no traces and no metrics for the app services because the upstream containers are not instrumented for OpenTelemetry.
- Browser plugin automation was unavailable due a local sandbox bootstrap failure, so dashboard validation used headless Chrome/CDP fallback.
- The AppHost uses Aspire `13.3.5` rather than `9.0.0` because Aspire `9.0.0` dashboard assets did not render under the installed .NET 10 environment.

## Result

Functional HTTP workflow equivalence passed. Full observability equivalence did not pass because traces and metrics were not visible.

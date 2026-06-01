# Compose to Aspire Migration Design

## Objective

Migrate Docker's Example Voting App from the imported `docker-compose.yml` into a .NET Aspire AppHost while preserving externally observable behavior and startup ordering.

No migration implementation was performed before this design was written.

## Source Service Topology

| Service | Runtime | Compose definition | Ports | Dependencies | Networks |
| --- | --- | --- | --- | --- | --- |
| `vote` | Python/Flask | `build.context=./vote`, `target=dev` | `8080:80` | `redis` healthy | `front-tier`, `back-tier` |
| `result` | Node.js | `build=./result`, `entrypoint=nodemon --inspect=0.0.0.0 server.js` | `8081:80`, `127.0.0.1:9229:9229` | `db` healthy | `front-tier`, `back-tier` |
| `worker` | .NET worker | `build.context=./worker` | none | `redis` healthy, `db` healthy | `back-tier` |
| `redis` | Redis | `image=redis:alpine` | internal `6379` | none | `back-tier` |
| `db` | PostgreSQL | `image=postgres:15-alpine` | internal `5432` | none | `back-tier` |
| `seed` | Python seed job | `build=./seed-data`, profile `seed` | none | `vote` healthy | `front-tier` |

The `seed` service is not part of the default Compose deployment because it is gated behind the `seed` profile. The default Aspire migration will document it but not start it by default.

## Environment Variables

| Service | Environment variables |
| --- | --- |
| `vote` | none in Compose; app code supports `OPTION_A` and `OPTION_B` defaults of `Cats` and `Dogs`. Redis host is hardcoded as `redis`. |
| `result` | `PORT=80` from the Dockerfile. PostgreSQL connection string is hardcoded as `postgres://postgres:postgres@db/postgres`. |
| `worker` | none in Compose. PostgreSQL connection string is hardcoded as `Server=db;Username=postgres;Password=postgres;`; Redis host is hardcoded as `redis`. |
| `redis` | none. |
| `db` | `POSTGRES_USER=postgres`, `POSTGRES_PASSWORD=postgres`. |

Sensitive value handling:

- The Aspire AppHost should not add a plaintext PostgreSQL password default into source code.
- The database password should be represented as an Aspire secret parameter and provided during local validation with `Parameters__postgres-password=postgres` to match upstream application hardcoded defaults.
- A production migration should change the application code to read credentials from configuration before using non-demo credentials.

## Volumes And Persistence

| Compose volume | Purpose | Aspire plan |
| --- | --- | --- |
| `db-data:/var/lib/postgresql/data` | Persistent PostgreSQL data | Use Aspire PostgreSQL `WithDataVolume(...)` with an experiment-specific volume name. |
| `./healthchecks:/healthchecks` on `redis` and `db` | Healthcheck scripts only | Do not mount in Aspire; use Aspire-native resource readiness instead. |
| `./vote:/usr/local/app` | Local development bind mount for Flask dev target | Prefer final Dockerfile stage or an explicit bind mount if the dev target is required during iteration. |
| `./result:/usr/local/app` | Local development bind mount for Node/nodemon | Use the Dockerfile image contents and preserve nodemon/debug command where practical. |

## Health And Startup Behavior

Compose behavior:

- `vote` waits for `redis` to become healthy.
- `result` waits for `db` to become healthy.
- `worker` waits for both `redis` and `db` to become healthy.
- `vote` has an HTTP healthcheck against `http://localhost`.
- Redis and PostgreSQL use shell healthcheck scripts.

Aspire plan:

- Use `WaitFor(redis)` for `vote` and `worker`.
- Use `WaitFor(db)` or `WaitFor(postgresDatabase)` for `result` and `worker`.
- Add HTTP health checks for `vote` and `result` endpoints.
- Preserve external smoke testing for endpoint and workflow validation.

Known upstream startup race:

- During baseline validation, `result` briefly logged `relation "votes" does not exist` before `worker` created the table.
- The migration may add `result.WaitFor(worker)` if required to reduce this non-fatal startup race, but the initial implementation should preserve the primary Compose dependency shape unless validation shows a practical issue.

## Proposed Aspire Resource Mapping

| Compose service | Aspire resource | Rationale |
| --- | --- | --- |
| `redis` | `builder.AddRedis("redis").WithImageTag("alpine")` | Aspire-native resource while preserving the DNS name expected by source code. |
| `db` | `builder.AddPostgres("db", user, password).WithImageTag("15-alpine").WithDataVolume(...)` plus `AddDatabase("postgres")` | Aspire-native PostgreSQL with persistence and the database name expected by source code. |
| `vote` | `builder.AddDockerfile("vote", source/vote, stage: "final")` | Source-based image build. Final stage embeds source code and avoids requiring a bind mount for the dev stage. |
| `result` | `builder.AddDockerfile("result", source/result)` | Source-based image build. Preserve `8081:80`; preserve debug port `9229` where practical. |
| `worker` | `builder.AddDockerfile("worker", source/worker)` | Source-based image build for the .NET worker. |
| `seed` | Not started by default | Compose default does not start the profile-gated seed service. |

## Port Mapping

| Function | Compose | Aspire plan |
| --- | --- | --- |
| Vote HTTP | host `8080` -> container `80` | host `8080` -> container `80` |
| Result HTTP | host `8081` -> container `80` | host `8081` -> container `80` |
| Result debugger | host `127.0.0.1:9229` -> container `9229` | expose host `9229` if validation shows no conflict; Aspire may not preserve loopback-only binding exactly. |
| Redis | internal `6379` | internal Aspire resource endpoint; no public host port planned. |
| PostgreSQL | internal `5432` | internal Aspire resource endpoint with persisted data; no public host port planned. |

## Migration Risks

- The application source hardcodes `redis`, `db`, and PostgreSQL demo credentials. Aspire resource names must preserve `redis` and `db`.
- Avoiding plaintext secrets in AppHost source requires supplying `Parameters__postgres-password=postgres` during local validation.
- The source Compose file uses development bind mounts and nodemon. Aspire source-built containers may not provide live-reload semantics unless bind mounts are explicitly added.
- The upstream worker Dockerfile uses .NET 7 runtime images, which are end-of-life. The migration preserves upstream behavior for equivalence, but this is a maintainability risk.
- Docker Compose plugin command `docker compose` is unavailable in this environment; validation uses Docker Desktop's `docker-compose` compatibility command.
- The local .NET environment initially lacked the `Aspire.AppHost.Sdk` package. The implementation should prefer a simple project shape that builds with cached Aspire Hosting packages when possible, and document any restore requirements.

## Validation Plan

1. Create Aspire AppHost under `experiments/03-codex-desktop-voting-app/aspire`.
2. Run `dotnet build`.
3. Start the AppHost with the PostgreSQL password parameter set to `postgres`.
4. Run `tests/smoke.sh` against `http://localhost:8080` and `http://localhost:8081`.
5. Inspect Aspire Dashboard resources, logs, endpoints, traces, and metrics.
6. Document differences and any validation gaps.

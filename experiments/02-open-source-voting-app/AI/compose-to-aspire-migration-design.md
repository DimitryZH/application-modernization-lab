# Compose to Aspire Migration Design

## Source service topology

| Service | Source type | Image/build | Ports | Dependencies | Networks |
| --- | --- | --- | --- | --- | --- |
| `vote` | Web app | `dockersamples/examplevotingapp_vote` | `8080:80` | `redis` healthy | `front-tier`, `back-tier` |
| `result` | Web app | `dockersamples/examplevotingapp_result` | `8081:80` | `db` healthy | `front-tier`, `back-tier` |
| `worker` | Background worker | `dockersamples/examplevotingapp_worker` | none | `redis` healthy, `db` healthy | `back-tier` |
| `redis` | Data service | `redis:alpine` | private 6379 | none | `back-tier` |
| `db` | Data service | `postgres:15-alpine` | private 5432 | none | `back-tier` |

## Environment variables

- `db` sets `POSTGRES_USER=postgres` and `POSTGRES_PASSWORD=postgres`.
- Application containers are expected to use the Compose DNS names `redis` and `db`. Compatibility environment variables (`REDIS_HOST`, `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) will be added in Aspire to support newer app revisions without changing behavior for hardcoded-host images.

## Volumes

- Compose uses named volume `db-data` mounted at `/var/lib/postgresql/data`.
- Compose mounts `./healthchecks` into Redis and PostgreSQL only for health commands.
- Aspire should preserve PostgreSQL persistence with a named data volume. Healthcheck scripts are not required if using Aspire-native resource health/readiness and `WaitFor`.

## Health/readiness behavior

- Compose gates app startup using Redis and PostgreSQL healthchecks.
- Aspire should use `WaitFor(redis)` and `WaitFor(db)` for dependent app resources.
- Web availability is validated externally by smoke tests against `http://localhost:8080` and `http://localhost:8081`.

## Proposed Aspire mapping

| Compose resource | Aspire resource | Rationale |
| --- | --- | --- |
| `redis` | `builder.AddRedis("redis")` | Aspire-native Redis resource; preserves service name and readiness handling. |
| `db` | `builder.AddPostgres("db", user, password)` | Aspire-native PostgreSQL resource; preserves service name and persistent data. |
| `vote` | `builder.AddContainer("vote", "dockersamples/examplevotingapp_vote")` | Prebuilt upstream image selected for source import; exposes host 8080 to target 80. |
| `result` | `builder.AddContainer("result", "dockersamples/examplevotingapp_result")` | Prebuilt upstream image selected for source import; exposes host 8081 to target 80. |
| `worker` | `builder.AddContainer("worker", "dockersamples/examplevotingapp_worker")` | Background worker image; no public endpoint. |

## Migration risks

- Direct full-source import was blocked by environment HTTP 403 responses, so this experiment validates image-based migration rather than Dockerfile-backed source builds.
- The execution environment does not include Docker, Podman, nerdctl, or dotnet, so runtime and build validation may be blocked locally.
- The prebuilt application images may use hardcoded hostnames `redis` and `db`; Aspire resource names are chosen to preserve those DNS names.
- Image tags are not pinned to digests in this experiment, matching the upstream image Compose file but reducing supply-chain reproducibility.

## Manual decisions required

- For production, pin image tags/digests and use non-default PostgreSQL credentials.
- Decide whether future experiments should import full source and use `AddDockerfile` once GitHub clone/archive access and a container runtime are available.
- Decide whether smoke tests should inspect database rows directly; current tests validate externally observable HTTP behavior and process state when Compose is available.

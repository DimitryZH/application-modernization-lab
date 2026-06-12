# Stage C.2: Infrastructure Layer Report

## Result

**PASS**

Stage C.2 added the first four infrastructure resources to the Experiment 05
Aspire AppHost and established the initial image-lock inventory. Build and
static topology validation passed. A limited AppHost startup was attempted but
the DevBox DCP API server timed out before any resources were created, so
targeted direct-container checks were used to validate the critical
infrastructure contracts without disturbing the Stage A stack.

## Resources Added

| Resource | Representation | Image |
| --- | --- | --- |
| `astronomy-db` | Explicit container | `postgres:17.8`, pinned by Stage A digest |
| `valkey-cart` | Explicit container | `ghcr.io/valkey-io/valkey:9.0.2-alpine3.23`, pinned by Stage A digest |
| `flagd` | Explicit container | `ghcr.io/open-feature/flagd:v0.14.2`, pinned by Stage A digest |
| `llm` | Explicit container | `ghcr.io/open-telemetry/demo:latest-llm`, pinned by Stage A digest |

Explicit containers were selected for all four resources because they preserve
the Stage A images, commands, users, endpoints, and mount contracts directly.
No Kafka, Collector, observability backend, or additional application resource
was added.

## PostgreSQL Representation

`astronomy-db` preserves:

- PostgreSQL `17.8`;
- the `postgres -c shared_preload_libraries=pg_stat_statements` command;
- the upstream `astronomy_user` and `monitoring_user` roles;
- the `astronomy_db` database;
- the `accounting`, `catalog`, and `reviews` schemas;
- upstream tables, grants, and seed data;
- an internal named `postgres` endpoint on target port `5432`.

The upstream SQL contained hardcoded role passwords. Its tracked copy changes
only those two literals to psql variables. An Aspire-specific initialization
adapter passes secret parameter values to the SQL file. The administrator,
application-user, and monitoring-user passwords have no tracked defaults.

The Stage C.1 role-specific password placeholders were replaced with the exact
upstream role model:

- `postgres-password`;
- `astronomy-user-password`;
- `monitoring-user-password`.

## Other Resource Contracts

`valkey-cart` preserves the exact Valkey image, whose image-level user is
`valkey`, and declares an internal named `valkey` endpoint on target port
`6379`.

`flagd` preserves:

- gRPC target port `8013`;
- OFREP target port `8016`;
- the upstream start command and file URI;
- memory and OpenTelemetry environment intent;
- a narrow read-only mount of the tracked flag definition file.

`llm` preserves:

- HTTP target port `8000`;
- `FLAGD_HOST=flagd` and `FLAGD_PORT=8013`;
- a flagd endpoint reference and service-start dependency;
- an HTTP health check on `/v1/models`.

## Image Lock

Created `aspire/image-lock.json` with four Stage C.2 entries. Every entry
records the service, repository, original Stage A tag, immutable digest, image
ID, capture source, date, and notes.

The digests were captured from the running Stage A containers before Stage C.2
startup attempts. AppHost declarations preserve readable tags and pin the
captured digests with `WithImageSHA256`.

## Configuration Assets

| Asset | State |
| --- | --- |
| `configuration-assets/flagd/demo.flagd.json` | Unchanged from pinned upstream commit |
| `configuration-assets/postgres/init.sql` | Adapted only to replace two password literals with psql variables |
| `configuration-assets/postgres/01-init.sh` | Aspire-specific secret-parameter adapter |

The pinned upstream checkout remained clean and unmodified.

## Build Validation

Commands executed from `experiments/05-opentelemetry-demo/aspire/`:

```bash
dotnet build
dotnet build --no-restore
```

Both builds succeeded with zero errors. The existing `NU1903` warning remains
for the transitive `MessagePack 2.5.192` dependency.

## Static Topology Validation

Aspire manifest publication succeeded and confirmed:

- exactly four Stage C.2 container resources;
- all four images use immutable digest references;
- PostgreSQL secret parameters remain expression references;
- expected commands, mounts, environment variables, and named endpoints;
- the LLM-to-flagd endpoint reference.

The manifest publisher also logged a sandbox-only auxiliary backchannel socket
permission error after writing the manifest. The manifest itself was produced
successfully.

## Partial Runtime Validation

The limited AppHost startup did not create resources because DCP failed to
become available within its built-in 20-second timeout. The Stage A Compose
stack remained running and was not modified.

Targeted direct-container validation then confirmed:

- the adapted PostgreSQL init process completes successfully;
- schemas `accounting`, `catalog`, and `reviews` exist;
- `50` review rows and `10` product rows are loaded;
- `pg_stat_statements` is preloaded;
- parameterized `astronomy_user` and `monitoring_user` authentication works;
- the LLM `/v1/models` endpoint returns `astronomy-llm`.

The first direct flagd validation exposed an overly broad directory-mount
permission risk. The AppHost mount was narrowed to the single tracked JSON
file. The corrected flagd mount is confirmed by the generated Aspire manifest,
but a second direct flagd runtime check was not completed.

## Known Issues and Remaining Risks

1. Full AppHost partial startup remains blocked by the DevBox DCP API-server
   timeout and must be retried before Stage D conclusions.
2. The corrected single-file flagd mount still needs direct runtime
   confirmation.
3. flagd is configured to export metrics to the future `otel-collector`
   resource, which is intentionally absent until Stage C.5.
4. The known transitive `MessagePack 2.5.192` `NU1903` warning remains.
5. Stage C.3 must preserve Kafka listener, readiness, telemetry, and digest
   contracts without changing this infrastructure layer.

## Scope Confirmation

Stage C.2 did not add Kafka, accounting, checkout, frontend, the Collector,
Grafana, Jaeger, Prometheus, OpenSearch, or any other application service. No
Compose file or upstream source file was modified.

## Suggested Commit Message

```text
feat(experiment-05): add Aspire infrastructure layer
```

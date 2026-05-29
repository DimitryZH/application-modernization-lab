# Compose to Aspire Migration Design

## Scope

This document captures the proposed migration design for the existing Docker Compose demo application. It is intentionally limited to analysis and planning. No Aspire project, AppHost code, application code changes, or Docker Compose changes are included in this task.

The Docker Compose baseline has already been validated successfully per task context:

- `docker compose config` passed
- `docker compose build` passed
- `docker compose up -d` worked
- Services started successfully
- Smoke tests passed
- `docker compose down` completed

## Files inspected

- `docker-compose.yaml`
- `api/Dockerfile`
- `api/package.json`
- `api/server.js`
- `worker/Dockerfile`
- `worker/package.json`
- `worker/worker.js`
- `frontend/Dockerfile`
- `frontend/package.json`
- `frontend/server.js`
- `tests/smoke.sh`
- `README.md`
- `AGENTS.md`

## Current Docker Compose topology

| Service | Source | Responsibility | Host ports | Container ports | Persistence |
| --- | --- | --- | --- | --- | --- |
| `api` | Docker build context `./api` | Express API for health checks and todo CRUD backed by PostgreSQL and Redis | `8080` | `8080` | None directly |
| `worker` | Docker build context `./worker` | Background heartbeat writer for PostgreSQL and Redis | None | None | None directly |
| `frontend` | Docker build context `./frontend` | Express frontend and frontend health endpoint | `3000` | `3000` | None |
| `postgres` | Image `postgres:16` | PostgreSQL database for API todos and worker heartbeats | `5432` | `5432` | Named volume `postgres-data` |
| `redis` | Image `redis:7` | Redis cache and worker status store | `6379` | `6379` | None |

All Compose services run on the default Compose network and use service names for internal DNS:

- `api` reaches PostgreSQL at `postgres:5432`
- `api` reaches Redis at `redis:6379`
- `worker` reaches PostgreSQL at `postgres:5432`
- `worker` reaches Redis at `redis:6379`
- `frontend` is configured to call `api:8080`

## Services and responsibilities

### `api`

The API is a Node.js 20 Alpine container running `npm start`, which executes `node server.js`.

Responsibilities:

- Starts an Express server on `APP_PORT`, defaulting to `8080`.
- Connects to PostgreSQL using `DATABASE_URL`.
- Connects to Redis using `REDIS_URL`.
- Creates the `todos` table during startup if it does not exist.
- Exposes `GET /health`, which checks both PostgreSQL and Redis.
- Exposes `POST /todos`, which inserts a todo row and stores `last_todo_title` in Redis.
- Exposes `GET /todos`, which reads recent todos from PostgreSQL and returns the Redis cached title.

### `worker`

The worker is a Node.js 20 Alpine container running `npm start`, which executes `node worker.js`.

Responsibilities:

- Connects to PostgreSQL using `DATABASE_URL`.
- Connects to Redis using `REDIS_URL`.
- Creates the `worker_heartbeats` table during startup if it does not exist.
- Every 5 seconds, inserts a `worker alive` heartbeat row in PostgreSQL.
- Every 5 seconds, sets `worker_status=alive` in Redis.

The worker has no exposed HTTP endpoint.

### `frontend`

The frontend is a Node.js 20 Alpine container running `npm start`, which executes `node server.js`.

Responsibilities:

- Starts an Express server on port `3000`.
- Reads `API_BASE_URL`, defaulting to `http://localhost:8080`.
- Exposes `GET /`, which renders a simple HTML page showing the configured API base URL.
- Exposes `GET /health`, which returns frontend status and the configured API base URL.

The current frontend does not proxy API traffic and the smoke test only validates its health endpoint.

### `postgres`

PostgreSQL uses the `postgres:16` image.

Responsibilities:

- Hosts database `demo`.
- Uses user `demo`.
- Uses password `demo` in Compose.
- Stores data in the named Compose volume `postgres-data`.
- Provides the backing store for API todos and worker heartbeats.

### `redis`

Redis uses the `redis:7` image.

Responsibilities:

- Provides cache/state storage for `last_todo_title`.
- Provides worker liveness state via `worker_status`.
- Runs without a configured data volume in Compose.

## Ports and endpoints

| Endpoint | Compose access | Purpose |
| --- | --- | --- |
| API HTTP | `http://localhost:8080` | External API access and smoke tests |
| API health | `http://localhost:8080/health` | Validates API, PostgreSQL, and Redis connectivity |
| API todos | `http://localhost:8080/todos` | Create and read todo data |
| Frontend HTTP | `http://localhost:3000` | External frontend access and smoke tests |
| Frontend health | `http://localhost:3000/health` | Validates frontend process and configured API URL |
| PostgreSQL | `localhost:5432` and `postgres:5432` internally | Database access |
| Redis | `localhost:6379` and `redis:6379` internally | Redis access |

The smoke test defaults are:

- `API_URL=http://localhost:8080`
- `FRONTEND_URL=http://localhost:3000`

The future Aspire implementation should preserve host ports `8080` and `3000` if possible so `tests/smoke.sh` can run unchanged. If Aspire must use different host ports, validation should pass `API_URL` and `FRONTEND_URL` explicitly without reducing test coverage.

## Environment variables

### `api`

| Variable | Current Compose value | Notes |
| --- | --- | --- |
| `APP_PORT` | `8080` | Must remain aligned with the API container HTTP endpoint |
| `DATABASE_URL` | `postgres://demo:demo@postgres:5432/demo` | Must be preserved or generated in the same URL shape expected by the Node `pg` client |
| `REDIS_URL` | `redis://redis:6379` | Must be preserved or generated in the same URL shape expected by the Redis client |

### `worker`

| Variable | Current Compose value | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `postgres://demo:demo@postgres:5432/demo` | Same database as the API |
| `REDIS_URL` | `redis://redis:6379` | Same Redis instance as the API |

### `frontend`

| Variable | Current Compose value | Notes |
| --- | --- | --- |
| `API_BASE_URL` | `http://api:8080` | Internal service URL shown by the frontend and returned by `/health` |

### `postgres`

| Variable | Current Compose value | Notes |
| --- | --- | --- |
| `POSTGRES_USER` | `demo` | Future Aspire design should preserve user name unless the application connection strings are updated consistently |
| `POSTGRES_PASSWORD` | `demo` | Should become an Aspire secret parameter rather than a hardcoded source value |
| `POSTGRES_DB` | `demo` | Database name expected by current connection strings |

### `redis`

No environment variables are configured in Compose.

## Volumes and persistence

| Volume | Mounted by | Mount path | Purpose | Aspire requirement |
| --- | --- | --- | --- | --- |
| `postgres-data` | `postgres` | `/var/lib/postgresql/data` | Persistent PostgreSQL data | Preserve as an Aspire data volume or equivalent persistent container volume |

Redis has no configured persistence. The future Aspire design should keep Redis volatile unless a product decision is made to change behavior.

## Startup dependencies

Compose dependency behavior:

- `api` waits for `postgres` to be healthy.
- `api` waits for `redis` to be started.
- `worker` waits for `postgres` to be healthy.
- `worker` waits for `redis` to be started.
- `frontend` depends on `api` startup only.

Application startup behavior:

- `api` exits on startup if it cannot connect to Redis or create the PostgreSQL table.
- `worker` exits on startup if it cannot connect to Redis or create the PostgreSQL table.
- `frontend` starts independently as long as its Node process can bind port `3000`.

Aspire should model these dependencies with resource references and startup ordering:

- API waits for PostgreSQL database and Redis resources.
- Worker waits for PostgreSQL database and Redis resources.
- Frontend waits for API.

## Health and readiness behavior

Compose health checks:

- `postgres` defines a health check using `pg_isready -U demo -d demo`, with 5 second interval, 5 second timeout, and 10 retries.
- `api`, `worker`, `frontend`, and `redis` do not define Docker health checks.

Application readiness signals:

- `GET /health` on the API is the strongest readiness check because it verifies the API process, PostgreSQL, and Redis.
- `GET /health` on the frontend verifies the frontend process and reports its configured API URL.
- The worker has no direct readiness endpoint. The observable readiness signal is successful startup plus recurring `worker heartbeat written` logs or records in `worker_heartbeats`.

Future Aspire validation should use the existing smoke test as the required external readiness check and should also inspect AppHost/container logs if startup ordering or worker behavior is suspect.

## Proposed Aspire resource mapping

| Compose service | Proposed Aspire resource | Notes |
| --- | --- | --- |
| `postgres` | Aspire PostgreSQL resource | Prefer Aspire PostgreSQL hosting integration. Pin or configure PostgreSQL 16 behavior. Preserve database name `demo`, user `demo`, and persistent data volume. Store password as an Aspire secret parameter. |
| `redis` | Aspire Redis resource | Prefer Aspire Redis hosting integration. Pin or configure Redis 7 behavior if the integration allows image tag selection. Keep Redis without persistent data unless requirements change. |
| `api` | Dockerfile-backed container resource | Use the existing `api/Dockerfile` and preserve port `8080`, `APP_PORT`, `DATABASE_URL`, and `REDIS_URL`. Add references to PostgreSQL and Redis and wait for both. |
| `worker` | Dockerfile-backed container resource | Use the existing `worker/Dockerfile` and preserve `DATABASE_URL` and `REDIS_URL`. Add references to PostgreSQL and Redis and wait for both. |
| `frontend` | Dockerfile-backed container resource | Use the existing `frontend/Dockerfile`, preserve port `3000`, and preserve `API_BASE_URL=http://api:8080`. Add reference to API and wait for API. |

Important implementation note: the Node applications currently read `DATABASE_URL`, `REDIS_URL`, and `API_BASE_URL`. Aspire `WithReference` relationships may expose connection information through Aspire-standard environment variable names that these apps do not read. The future AppHost should both model relationships with `WithReference` and explicitly provide the legacy environment variable names required by the existing code, unless the application code is intentionally changed in a separate migration step.

## Proposed AppHost structure

Recommended future layout:

```text
src/
  AppHost/
    AppHost.csproj
    Program.cs
```

Recommended AppHost responsibilities:

1. Create a distributed application builder.
2. Define an Aspire secret parameter for the PostgreSQL password.
3. Define PostgreSQL as an Aspire-native resource:
   - Logical resource name: `postgres`
   - Image/version intent: PostgreSQL 16
   - Database: `demo`
   - User: `demo`
   - Persistent data volume equivalent to Compose `postgres-data`
   - Optional fixed host port `5432` if local database access parity is required
4. Define Redis as an Aspire-native resource:
   - Logical resource name: `redis`
   - Image/version intent: Redis 7
   - Optional fixed host port `6379` if local Redis access parity is required
5. Define API as a Dockerfile-backed resource:
   - Docker context: existing `api` directory
   - HTTP endpoint: container port `8080`, preferably host port `8080`
   - Environment:
     - `APP_PORT=8080`
     - `DATABASE_URL=postgres://demo:<postgres-password>@postgres:5432/demo`
     - `REDIS_URL=redis://redis:6379`
   - References:
     - PostgreSQL database
     - Redis
   - Startup ordering:
     - Wait for PostgreSQL database
     - Wait for Redis
6. Define worker as a Dockerfile-backed resource:
   - Docker context: existing `worker` directory
   - Environment:
     - `DATABASE_URL=postgres://demo:<postgres-password>@postgres:5432/demo`
     - `REDIS_URL=redis://redis:6379`
   - References:
     - PostgreSQL database
     - Redis
   - Startup ordering:
     - Wait for PostgreSQL database
     - Wait for Redis
7. Define frontend as a Dockerfile-backed resource:
   - Docker context: existing `frontend` directory
   - HTTP endpoint: container port `3000`, preferably host port `3000`
   - Environment:
     - `API_BASE_URL=http://api:8080`
   - References:
     - API
   - Startup ordering:
     - Wait for API

The exact relative Dockerfile paths should be chosen after the AppHost project is created. If `src/AppHost` is used, the existing service directories will be reached from the AppHost project via paths relative to `src/AppHost`.

## Validation strategy for the future Aspire version

The future implementation should validate equivalence in this order:

1. Confirm the Compose baseline remains valid if there have been any source changes since the known-good baseline:
   - `docker compose config`
   - `docker compose build`
   - `docker compose up -d`
   - `./tests/smoke.sh`
   - `docker compose down`
2. Build the Aspire solution:
   - `dotnet build`
3. Start the Aspire AppHost:
   - `dotnet run --project src/AppHost/AppHost.csproj`
4. Verify the AppHost starts all resources:
   - PostgreSQL is running and healthy.
   - Redis is running.
   - API is listening on its configured endpoint.
   - Worker is running and writing heartbeat logs.
   - Frontend is listening on its configured endpoint.
5. Run the same smoke test against Aspire:
   - If ports are preserved: `./tests/smoke.sh`
   - If ports differ: run with `API_URL` and `FRONTEND_URL` set to the Aspire host endpoints.
6. Inspect Aspire resource logs if the smoke test fails.
7. Do not claim functional equivalence until `dotnet build`, AppHost startup, and the smoke test pass.

## Known risks or manual decisions

- PostgreSQL credentials are hardcoded as `demo/demo` in Compose. Aspire should use a secret parameter for the password, but the generated `DATABASE_URL` must still match what the Node apps expect.
- Aspire resource references alone may not produce the exact `DATABASE_URL`, `REDIS_URL`, and `API_BASE_URL` variables used by the current app code. The AppHost should explicitly set these variables.
- Fixed host ports `8080`, `3000`, `5432`, and `6379` preserve Compose parity but can conflict with local developer processes. If fixed ports are not used, smoke test environment variables must be supplied during validation.
- Compose sets explicit container names. Aspire-generated container names will likely differ. Application behavior should not depend on container names, only logical service DNS names.
- PostgreSQL persistence must be preserved. Existing data in a reused volume can affect manual inspection, although the smoke test is tolerant because it searches for the inserted todo title.
- Redis is currently volatile. Adding Redis persistence during migration would be a behavior change.
- The worker is not covered by `tests/smoke.sh`. Future validation should at least inspect logs for `worker heartbeat written`, or a separate non-invasive verification can be added in a later task if broader coverage is desired.
- The Dockerfiles install dependencies without lockfiles. Dependency resolution may drift over time, which can affect both Compose and Aspire builds.
- PostgreSQL and Redis image tags should be pinned or otherwise controlled to avoid accidental version drift from the Compose baseline.

## Known differences expected from Aspire

- Aspire will introduce an AppHost and dashboard/orchestration layer that does not exist in Docker Compose.
- Aspire container names, network names, and volume names may differ from Compose-generated names.
- PostgreSQL password handling should move from a plain Compose value to an Aspire secret parameter.
- Aspire may expose service discovery and connection strings in additional environment variables. These should be additive and should not replace the legacy variables unless application code is intentionally updated.

## Recommended next implementation step

Create the Aspire AppHost skeleton under `src/AppHost`, add the required Aspire hosting integrations for PostgreSQL and Redis, and define the five resources in dependency order while preserving the existing environment variable contract and external API/frontend ports. After that, run `dotnet build`, start the AppHost, and execute `tests/smoke.sh` against the Aspire endpoints.

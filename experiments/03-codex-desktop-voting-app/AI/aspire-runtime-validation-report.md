# Aspire Runtime Validation Report

## Summary

Result: `PASS` for build, AppHost startup, resource startup, endpoints, and smoke test.

The Aspire migration builds and runs locally. The same smoke workflow used for Compose passed against the Aspire deployment after iterative AppHost fixes.

## Final AppHost Configuration

- Target framework: `net10.0`
- Aspire packages: `13.3.5`
- AppHost SDK: `Aspire.AppHost.Sdk` `13.3.5`
- PostgreSQL password provided at runtime with `Parameters__postgres-password=postgres`
- Dashboard URL: `http://localhost:15396`

## Commands Executed

From `experiments/03-codex-desktop-voting-app/aspire`:

```powershell
dotnet build
```

Final result:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

Final AppHost startup command:

```powershell
Set-Item -Path Env:Parameters__postgres-password -Value 'postgres'
dotnet run --project src\AppHost\AppHost.csproj --no-build --launch-profile http
```

Final smoke command from `experiments/03-codex-desktop-voting-app`:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc './tests/smoke.sh'
```

## Runtime Evidence

Final AppHost log evidence:

```text
Aspire version: 13.3.5+70b33bcb5f64c75e3ab6f57616545f35bd43dc81
Distributed application starting.
Now listening on: http://localhost:15396
Distributed application started. Press Ctrl+C to shut down.
```

Final Docker resource evidence:

| Resource | Image | Status | Endpoint evidence |
| --- | --- | --- | --- |
| `db` | `postgres:15-alpine` | Running | PostgreSQL ready to accept connections |
| `redis` | `redis:alpine` | Running | Redis ready to accept TCP connections |
| `vote` | source-built `vote:*` | Running | `http://localhost:8080` |
| `result` | source-built `result:*` | Running | `http://localhost:8081`, `tcp://localhost:9229` |
| `worker` | source-built `worker:*` | Running | Processed submitted vote |

Final smoke output:

```text
PASS: vote responded at http://localhost:8080
PASS: result responded at http://localhost:8081
PASS: vote page contains expected voting text
PASS: result page contains expected result text
PASS: basic vote flow submitted a vote and result endpoint remained readable
```

## Runtime Log Review

Positive evidence:

- `vote` accepted `POST /` with HTTP 200.
- `worker` logged `Processing vote for 'a'`.
- `result` logged `App running on port 80` and `Connected to db`.
- Redis logged `Ready to accept connections tcp`.
- PostgreSQL logged `database system is ready to accept connections`.

Non-critical findings:

- Aspire warned that no trusted development certificate was found. The AppHost uses HTTP for this local experiment, so this did not block validation.
- Redis warns that authentication is disabled. This is intentionally configured with `WithPassword(null!)` to preserve upstream Compose behavior.
- PostgreSQL emitted one transient `FATAL: the database system is starting up` during readiness probing before it became ready. The database then started normally and smoke validation passed.

## Fixes Applied During Runtime Validation

- Added `Aspire.AppHost.Sdk` after .NET 10 rejected workload-style AppHost metadata.
- Added explicit dashboard/resource-service/OTLP launch profile values.
- Updated Aspire packages from `9.0.0` to `13.3.5` because the Aspire 9 dashboard did not render correctly on the installed .NET 10 environment.
- Disabled Redis authentication to match upstream Compose no-auth Redis behavior.
- Removed the unnecessary PostgreSQL child database resource because the upstream app uses the default `postgres` database.

## Result

Aspire runtime validation passed for build, AppHost startup, resource startup, endpoint reachability, and functional smoke testing.

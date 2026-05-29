# Compose to Aspire Migration Implementation Report

## Summary

The Docker Compose demo has been migrated to a .NET Aspire AppHost without modifying the existing application services, Dockerfiles, Docker Compose file, or smoke test.

The Aspire migration keeps the three Node.js services Dockerfile-backed and uses Aspire-native PostgreSQL and Redis resources.

## Changed files

- `ComposeToAspireDemo.sln`
- `src/AppHost/AppHost.csproj`
- `src/AppHost/Program.cs`
- `src/AppHost/Properties/launchSettings.json`
- `src/AppHost/appsettings.json`
- `src/AppHost/appsettings.Development.json`
- `AI/compose-to-aspire-migration-implementation-report.md`

## Aspire topology

| Aspire resource | Implementation | Compose equivalent | Notes |
| --- | --- | --- | --- |
| `postgres` | Aspire PostgreSQL hosting integration | `postgres:16` | Uses image tag `16`, database `demo`, user parameter default `demo`, persistent data volume `postgres-data`, and secret parameter `postgres-password`. |
| `redis` | Aspire Redis hosting integration | `redis:7` | Uses image tag `7`; no persistence configured, matching Compose behavior. |
| `api` | `AddDockerfile("api", "../../api")` | `api` service built from `./api` | Exposes HTTP endpoint `8080`, sets `APP_PORT`, `DATABASE_URL`, and `REDIS_URL`, references and waits for PostgreSQL and Redis. |
| `worker` | `AddDockerfile("worker", "../../worker")` | `worker` service built from `./worker` | Sets `DATABASE_URL` and `REDIS_URL`, references and waits for PostgreSQL and Redis. |
| `frontend` | `AddDockerfile("frontend", "../../frontend")` | `frontend` service built from `./frontend` | Exposes HTTP endpoint `3000`, sets `API_BASE_URL=http://api:8080`, references and waits for API. |

## Secret handling

`POSTGRES_PASSWORD` is not hardcoded into source. The AppHost defines an Aspire secret parameter:

```csharp
builder.AddParameter("postgres-password", secret: true)
```

For validation, the parameter was supplied through the process environment as:

```powershell
Set-Item -Path Env:'Parameters__postgres-password' -Value 'demo'
```

This preserves the Compose baseline credential value for local parity without committing the password into source.

## Validation evidence

The local environment did not have `dotnet` on `PATH`, so a local .NET 9 SDK was installed under `C:\tmp\dotnet` for validation only.

Build command:

```powershell
$env:DOTNET_CLI_HOME=(Resolve-Path .).Path + '\.dotnet-probe'
$env:NUGET_PACKAGES=(Resolve-Path .).Path + '\.nuget-probe'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
& 'C:\tmp\dotnet\dotnet.exe' build
```

Build result:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

Run command:

```powershell
Set-Item -Path Env:'Parameters__postgres-password' -Value 'demo'
& 'C:\tmp\dotnet\dotnet.exe' run --project src\AppHost\AppHost.csproj --launch-profile http
```

Runtime evidence:

```text
Aspire version: 9.0.0
Distributed application started.
Now listening on: http://localhost:15196
```

Smoke test command:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' ./tests/smoke.sh
```

Smoke test result:

```text
Checking API health at http://localhost:8080/health
Creating test todo
Reading todos
Checking frontend health at http://localhost:3000/health
Smoke tests passed
```

Resource evidence during validation:

```text
frontend ... Up
worker   ... Up
api      ... Up
postgres ... Up
redis    ... Up
```

Created Aspire containers were removed after validation.

## Known differences from Docker Compose

- Aspire container names are generated dynamically instead of using Compose `container_name` values.
- Aspire uses its AppHost, dashboard, DCP orchestration, and local proxying in addition to Docker containers.
- The PostgreSQL password is now an Aspire secret parameter instead of a committed Compose-style literal in AppHost source.
- `tests/smoke.sh` was run through Git Bash on Windows. The default elevated `bash` resolved to WSL, where `localhost` is not the Windows host running Aspire.

## Manual follow-up items

- For normal local runs, set the Aspire secret parameter before launching:

  ```powershell
  Set-Item -Path Env:'Parameters__postgres-password' -Value 'demo'
  dotnet run --project src\AppHost\AppHost.csproj --launch-profile http
  ```

- If running from an environment where `bash` resolves to WSL, use Git Bash or set `API_URL` and `FRONTEND_URL` to endpoints reachable from that shell.
- The existing smoke test does not directly verify worker heartbeat rows. It does verify the AppHost starts the worker container; deeper worker assertions can be added later if desired.

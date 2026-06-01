# Compose to Aspire Demo

This repository is a controlled demo for testing AI-assisted migration from Docker Compose to .NET Aspire.

## Services

- `api` — Node.js Express API using PostgreSQL and Redis
- `worker` — background worker writing heartbeats to PostgreSQL and Redis
- `frontend` — simple Node.js Express frontend
- `postgres` — PostgreSQL 16 with named volume
- `redis` — Redis 7

## Run Docker Compose baseline

```bash
docker compose up -d --build
./tests/smoke.sh
docker compose logs --tail=100
docker compose down
```

## Run .NET Aspire version

Prerequisites:

- .NET 9 SDK with access to restore Aspire 9 packages/workloads
- Docker Desktop or another Docker-compatible container runtime
- NuGet access for first-time restore
- Bash for `tests/smoke.sh`; on Windows, Git Bash is preferred because WSL `localhost` may not reach the Windows-hosted Aspire endpoints

Set the PostgreSQL password parameter expected by the AppHost:

```powershell
$env:Parameters__postgres-password = "demo"
```

Build and start the AppHost:

```powershell
dotnet build
dotnet run --project src/AppHost/AppHost.csproj --launch-profile http
```

In another terminal, run the existing smoke test:

```bash
./tests/smoke.sh
```

On Windows with Git Bash installed, the smoke test can also be run as:

```powershell
& "C:\Program Files\Git\bin\bash.exe" ./tests/smoke.sh
```

For a one-command local validation helper, run:

```powershell
.\scripts\validate-aspire.ps1
```

## Expected smoke-test coverage

The smoke test verifies:

- API health endpoint
- PostgreSQL connectivity
- Redis connectivity
- create/read todo API behavior
- frontend health endpoint

## Migration task

Ask Codex to convert this Docker Compose application to a .NET Aspire AppHost and validate the result using the same smoke tests.

See `AGENTS.md` for the required agent workflow.

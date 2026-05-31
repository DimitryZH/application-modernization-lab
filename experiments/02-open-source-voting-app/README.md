# Experiment 02: Open Source Voting App Docker Compose to Aspire Migration

## Purpose

This experiment migrates the open-source Docker Example Voting App from a Docker Compose topology to a .NET Aspire AppHost topology.

## Source project

- Project: Docker Example Voting App
- Repository: https://github.com/dockersamples/example-voting-app
- Commit used: `63e9150` short SHA visible on the upstream commits page at retrieval time
- Retrieval date: 2026-05-31 UTC

> Note: direct `git clone`, GitHub archive, and GitHub API retrieval from the shell were blocked by HTTP 403 in this environment. The source import therefore contains the minimal image-based Compose topology using upstream prebuilt images.

## Directory layout

```text
experiments/02-open-source-voting-app/
├── source/   # Minimal source Compose assets selected for the experiment
├── aspire/   # Aspire AppHost migration
├── tests/    # Smoke tests
├── AI/       # Experiment reports and live iteration log
└── README.md
```

## Baseline Docker Compose topology

| Service | Image | Host endpoint | Role |
| --- | --- | --- | --- |
| `vote` | `dockersamples/examplevotingapp_vote` | http://localhost:8080 | Voting web UI |
| `result` | `dockersamples/examplevotingapp_result` | http://localhost:8081 | Results web UI |
| `worker` | `dockersamples/examplevotingapp_worker` | none | Transfers votes from Redis to PostgreSQL |
| `redis` | `redis:alpine` | private | Vote queue/cache |
| `db` | `postgres:15-alpine` | private | Persistent vote database |

## Aspire topology

| Resource | Aspire API | Endpoint |
| --- | --- | --- |
| `redis` | `AddRedis("redis")` | private 6379 |
| `db` | `AddPostgres("db")` | private 5432 |
| `vote` | `AddContainer("vote", "dockersamples/examplevotingapp_vote")` | http://localhost:8080 |
| `result` | `AddContainer("result", "dockersamples/examplevotingapp_result")` | http://localhost:8081 |
| `worker` | `AddContainer("worker", "dockersamples/examplevotingapp_worker")` | none |

## Prerequisites for reproduction

- Docker or another Aspire-supported container runtime.
- .NET 9 SDK.
- Network access to Docker Hub and NuGet.
- Bash and curl.

## Reproduce baseline Compose validation

```bash
cd experiments/02-open-source-voting-app/source
docker compose up -d
cd ../../..
COMPOSE_DIR=experiments/02-open-source-voting-app/source ./experiments/02-open-source-voting-app/tests/smoke.sh
docker compose -f experiments/02-open-source-voting-app/source/docker-compose.yml logs --tail=100
docker compose -f experiments/02-open-source-voting-app/source/docker-compose.yml down -v
```

## Reproduce Aspire validation

In one terminal:

```bash
dotnet build experiments/02-open-source-voting-app/aspire/VotingApp.Aspire.slnx
dotnet run --project experiments/02-open-source-voting-app/aspire/src/AppHost/AppHost.csproj
```

In another terminal after resources are running:

```bash
./experiments/02-open-source-voting-app/tests/smoke.sh
```

## Current validation status

This repository update was produced in an environment without Docker, Podman, nerdctl, or the .NET SDK. Therefore:

- Baseline Compose validation: **blocked / failed locally** (`docker: command not found`).
- Aspire build validation: **blocked / failed locally** (`dotnet: command not found`).
- Aspire runtime validation: **blocked / failed locally** (`dotnet: command not found`).
- Static syntax/topology checks: **passed**.

Final assessment: **PARTIAL_PASS**.

## Known differences from Docker Compose

- Aspire uses native Redis and PostgreSQL resource APIs rather than raw Compose services.
- Aspire uses `WaitFor` startup ordering instead of the exact Compose healthcheck scripts.
- The migration uses prebuilt app images rather than Dockerfile-backed source resources because full source retrieval and Docker builds were blocked in this environment.
- Image tags are not pinned to digests.

## Reports

See `AI/` for the full source report, baseline validation report, migration design, implementation report, review, final assessment, and live session iteration log.

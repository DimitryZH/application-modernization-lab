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

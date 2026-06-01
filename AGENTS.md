# AGENTS.md

## Project Goal

This repository contains controlled research experiments for testing whether Codex can migrate Docker Compose based applications to .NET Aspire.

Experiment 01, the original controlled demo, now lives under `experiments/01-controlled-demo`.

The goal is not only to generate Aspire code, but to validate functional equivalence between the original Docker Compose version and the Aspire version for each experiment.

## Expected Workflow

Before making migration changes:

1. Inspect the experiment's Compose file, such as `experiments/01-controlled-demo/docker-compose.yaml`.
2. Identify all services, ports, environment variables, volumes, dependencies, commands, health checks, and build contexts.
3. Run the original Docker Compose stack.
4. Execute the smoke tests.
5. Capture baseline validation results.

Migration steps:

1. Create a .NET Aspire AppHost project.
2. Convert Compose services into Aspire resources.
3. Use Aspire-native resources where appropriate:
   - PostgreSQL
   - Redis
4. Use `AddDockerfile`, `AddContainer`, or equivalent Aspire APIs for custom services.
5. Preserve:
   - exposed ports
   - environment variables
   - service dependencies
   - persistent data requirements
   - health/startup behavior
6. Use `WithReference` for service relationships.
7. Use `WaitFor` for startup ordering.

Validation steps:

1. Run `dotnet build`.
2. Start the Aspire AppHost.
3. Run the same smoke tests against the Aspire version.
4. If validation fails, inspect logs, fix the configuration, and repeat.
5. Do not claim success until validation commands pass.

## Commands

Baseline Docker Compose validation:

```bash
cd experiments/01-controlled-demo
docker compose up -d --build
./tests/smoke.sh
docker compose logs --tail=100
docker compose down
```

Aspire validation:

```bash
cd experiments/01-controlled-demo
dotnet build
dotnet run --project src/AppHost/AppHost.csproj
./tests/smoke.sh
```

If the Aspire app uses different local ports, update the smoke test configuration without weakening the test coverage.

## Success Criteria

The migration is successful only if:

1. Docker Compose version starts successfully.
2. Smoke tests pass against Docker Compose.
3. Aspire version builds successfully.
4. Aspire version starts successfully.
5. The same smoke tests pass against Aspire.
6. Remaining differences are documented.

## Required Output

At the end, provide:

1. List of changed files.
2. Final Aspire topology summary.
3. Validation evidence.
4. Known differences from Docker Compose.
5. Manual follow-up items, if any.

## Important Rules

- Do not remove existing app behavior.
- Do not skip validation.
- Do not hardcode secrets into source code.
- Prefer Aspire parameters for sensitive values.
- Do not claim functional equivalence without test evidence.
- If exact equivalence is not possible, explain the reason clearly.

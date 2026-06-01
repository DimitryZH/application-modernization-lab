# Aspire Migration Technical Review

## 1. Summary

The migration is a solid local-development conversion of the Docker Compose demo into a .NET Aspire AppHost. It preserves the main application topology: API, worker, frontend, PostgreSQL, and Redis. It also keeps the existing application code, Dockerfiles, Compose file, and smoke test unchanged.

The implementation has been validated with `dotnet build`, AppHost startup, and the unchanged smoke test. The biggest gaps are reproducibility and exact parity details: the PostgreSQL secret must be supplied externally, clean-environment SDK/Aspire requirements are not documented in the primary README, the worker is not directly covered by the smoke test, and PostgreSQL volume continuity is logically preserved but not proven to be the same physical Docker volume as Compose.

Overall score: **7/10** for a controlled demo migration.

Production readiness: **Not production-ready**. It is suitable as a validated local Aspire migration demo, but it needs clearer setup documentation, stronger verification, and deployment/security decisions before production use.

## 2. Strengths

- The migration keeps the application services unchanged.
- `docker-compose.yaml` is unchanged.
- `tests/smoke.sh` is unchanged.
- Aspire uses native PostgreSQL and Redis resources instead of wrapping both as generic containers.
- The API, worker, and frontend continue to use their existing Dockerfiles.
- The AppHost explicitly sets the legacy environment variables the Node apps actually consume: `DATABASE_URL`, `REDIS_URL`, `APP_PORT`, and `API_BASE_URL`.
- Startup ordering is modeled with `WaitFor`.
- Resource relationships are modeled with `WithReference`.
- API and frontend smoke-test ports remain `8080` and `3000`.
- PostgreSQL password is not hardcoded into AppHost source.
- The implementation report records the validation evidence and the Windows/Git Bash caveat.

## 3. Weaknesses

- A clean developer environment needs undocumented prerequisites: .NET 9 SDK, Aspire 9 package restore/workload support, Docker, NuGet access, and a configured PostgreSQL password parameter.
- `dotnet run --project src/AppHost/AppHost.csproj` will not be reproducible unless `Parameters__postgres-password` is supplied through environment, user secrets, or another configuration source.
- The main README was not updated with Aspire run instructions.
- The smoke test does not verify worker heartbeat behavior.
- The implementation hardcodes internal resource hostnames and ports inside `DATABASE_URL` and `REDIS_URL` expressions instead of deriving all parts from Aspire endpoint references.
- The Aspire PostgreSQL volume name preserves the logical persistence requirement, but the migration does not prove continuity with the Docker Compose-created volume.
- Validation required Git Bash on Windows because WSL `localhost` could not reach the Windows-hosted Aspire proxy. That is documented in AI reports but not in primary developer docs.

## 4. Migration Correctness Findings

### Services

The service set matches Compose:

- Compose `api` maps to Dockerfile-backed Aspire resource `api`.
- Compose `worker` maps to Dockerfile-backed Aspire resource `worker`.
- Compose `frontend` maps to Dockerfile-backed Aspire resource `frontend`.
- Compose `postgres:16` maps to Aspire PostgreSQL with image tag `16`.
- Compose `redis:7` maps to Aspire Redis with image tag `7`.

No application service code was modified.

### Dependencies and startup ordering

The dependency graph is mostly correct:

- API waits for PostgreSQL database and Redis.
- Worker waits for PostgreSQL database and Redis.
- Frontend waits for API.

This is at least as strict as Compose. Compose waits for PostgreSQL health for API/worker, Redis started for API/worker, and API startup for frontend. Aspire's Redis integration includes health behavior, so the Aspire Redis wait may be stricter than Compose's `service_started`.

### Ports

The smoke-test-critical ports are preserved:

- API endpoint: `localhost:8080`
- Frontend endpoint: `localhost:3000`

PostgreSQL and Redis are configured with port parameters (`5432` and `6379`), but the validation evidence in the implementation report showed Docker containers using dynamic host ports behind Aspire/DCP proxying. This may still provide the intended Aspire host endpoints while the AppHost is running, but direct parity for external `localhost:5432` and `localhost:6379` access was not explicitly validated.

### Environment variables

The required application-facing environment variables are preserved:

- API: `APP_PORT`, `DATABASE_URL`, `REDIS_URL`
- Worker: `DATABASE_URL`, `REDIS_URL`
- Frontend: `API_BASE_URL`

The AppHost correctly recognizes that Aspire-standard connection string variables alone would not be consumed by the Node apps.

### Persistence

PostgreSQL persistence is represented with `.WithDataVolume("postgres-data")`. Redis remains non-persistent, matching Compose.

Open parity question: Docker Compose normally prefixes named volumes with the Compose project name unless an explicit volume name is configured. Aspire's named volume may therefore not be the exact same physical Docker volume as the Compose baseline. This is acceptable for functional migration if data continuity is not required, but it should be documented as a difference.

### Secrets

The AppHost defines `postgres-password` as an Aspire secret parameter and does not commit the password into source. This is better than hardcoding the Compose `demo` password in AppHost code.

Reproducibility caveat: validation depends on supplying `Parameters__postgres-password=demo` externally to match the Compose baseline credential.

## 5. Reproducibility Findings

- The repository does not include a `global.json`, so SDK selection depends on the developer's installed SDKs.
- The AppHost targets `net9.0` and pins Aspire packages/SDK to `9.0.0`; a clean machine must have a compatible .NET 9 SDK and NuGet access.
- The local validation environment initially had no `dotnet` on `PATH`; this is documented in the implementation and iteration reports, but not in README.
- Aspire template/package restore required NuGet access.
- The AppHost secret parameter must be supplied before `dotnet run`.
- The validation command in `AGENTS.md` says `dotnet run --project src/AppHost/AppHost.csproj`; in the current implementation, the reproducible command also needs the PostgreSQL password parameter.
- On Windows, invoking `bash` may resolve to WSL instead of Git Bash. The unchanged smoke test passed with Git Bash, not WSL.
- There is no scripted one-command Aspire validation wrapper that sets required parameters, chooses the right Bash, starts AppHost, runs smoke, and cleans up.

## 6. Technical Debt Findings

- `DATABASE_URL` and `REDIS_URL` are manually assembled with resource names and fixed internal ports. This is simple and validated, but fragile if resource names, endpoint names, or ports change.
- The PostgreSQL user default `demo` is encoded in AppHost source. This is not a secret, but it is still a hardcoded environment assumption.
- The AppHost project uses fixed dashboard/resource service ports from the generated launch profile. These can conflict on shared developer machines.
- The solution has no README update documenting Aspire prerequisites and run commands.
- There is no CI/build workflow proving the Aspire AppHost remains buildable.
- The smoke test does not assert worker behavior.
- The review found minor formatting inconsistency in generated/edited XML and JSON files, likely from mixed line endings. This is cosmetic but avoidable.

## 7. Risk Assessment

### Operational risks

- Missing `postgres-password` configuration prevents AppHost startup.
- Existing PostgreSQL volumes initialized with a different password may fail authentication.
- Worker failures may go undetected by the current smoke test.

### Portability risks

- Windows Git Bash versus WSL behavior matters for the current smoke test invocation.
- Aspire proxy binding and Docker host networking can behave differently across Windows, WSL, macOS, and Linux.
- Fixed local ports may conflict with existing processes.

### Upgrade risks

- Aspire packages and AppHost SDK are pinned to `9.0.0`.
- Future Aspire versions may change endpoint/proxy behavior or APIs used by `AddDockerfile`, `WithReference`, or `WaitFor`.
- The manual `ReferenceExpression` connection strings are more exposed to API or endpoint changes than standard Aspire connection string consumption would be.

### Security risks

- The password is not committed, which is good.
- The app still receives the database password in `DATABASE_URL`, so it is present in container environment variables.
- The demo uses the Compose-compatible `demo` credential during validation; that is fine for local demo parity but not suitable for production.

## 8. Recommended Improvements

1. Add README instructions for Aspire prerequisites, including .NET 9 SDK, Docker, NuGet access, and how to set `Parameters__postgres-password`.
2. Add a small validation script for Aspire that starts the AppHost with the required parameter and runs the unchanged smoke test with the right shell/URLs.
3. Document that the Aspire PostgreSQL volume is logically equivalent but may not be the same Docker volume name used by Compose.
4. Add optional worker validation, such as checking worker logs or verifying a heartbeat row/key, without weakening the existing smoke test.
5. Consider deriving `DATABASE_URL` and `REDIS_URL` from Aspire endpoint references where practical, while preserving the Node apps' expected URL format.
6. Add `global.json` if the project should pin SDK selection for clean environments.
7. Consider documenting or parameterizing fixed dashboard/resource service ports to reduce local port conflict surprises.
8. Add CI validation for `dotnet build` once the environment can provide the Aspire workload/packages.

## 9. Overall Score

**7/10**

The migration is functionally validated and appropriately scoped for the demo. The main deductions are for clean-environment reproducibility, incomplete worker validation, and a few parity/documentation gaps.

## 10. Production Readiness Assessment

This migration is **not production-ready**.

It is a working local Aspire migration demo. Production readiness would require environment-specific secret management, deployment definitions, stronger operational checks, clearer data migration/persistence decisions, CI validation, and more complete documentation. The current solution is best understood as a validated development orchestration equivalent, not a deployment-ready architecture.

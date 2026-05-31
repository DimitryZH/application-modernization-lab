# Aspire Reproducibility Improvements Report

## Files changed

- `README.md`
- `scripts/validate-aspire.ps1`
- `AI/aspire-reproducibility-improvements-report.md`

## Reproducibility gaps addressed

- Added README instructions for running the Aspire version.
- Documented required prerequisites:
  - .NET 9 SDK
  - Docker-compatible container runtime
  - NuGet access for first-time restore
  - Bash for the existing smoke test
- Documented the required Aspire secret parameter:

  ```powershell
  $env:Parameters__postgres-password = "demo"
  ```

- Documented how to build and run the AppHost:

  ```powershell
  dotnet build
  dotnet run --project src/AppHost/AppHost.csproj --launch-profile http
  ```

- Documented how to run the unchanged smoke test.
- Added `scripts/validate-aspire.ps1` as a one-command local validation helper.
- The validation script prefers Git Bash on Windows when available, avoiding the known WSL `localhost` mismatch.
- The validation script sets `Parameters__postgres-password=demo`, runs `dotnet build`, starts the AppHost, waits for API and frontend health, runs `tests/smoke.sh`, and stops the AppHost after validation.
- The validation script performs a Docker daemon preflight after build so Docker availability failures are reported clearly.

## Commands executed

Validation script command executed in this environment:

```powershell
.\scripts\validate-aspire.ps1 -DotnetPath C:\tmp\dotnet\dotnet.exe
```

The explicit `-DotnetPath` argument was needed because this environment does not have `dotnet` on `PATH`. In a clean developer environment with the .NET SDK installed normally, the intended command is:

```powershell
.\scripts\validate-aspire.ps1
```

The script ran:

```powershell
dotnet build
```

Build result:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

The script then checked Docker availability before starting the AppHost.

## Validation result

Partial validation completed.

What passed:

- The new validation script executed.
- `dotnet build` completed successfully.
- The script restored the prior `Parameters__postgres-password` process environment value after running.
- The script failed fast with a clear Docker prerequisite message.

What did not run:

- AppHost startup did not run in the final script attempt because Docker daemon preflight failed.
- `tests/smoke.sh` did not run in the final script attempt because the AppHost could not be started without Docker.

Observed Docker failure:

```text
Docker daemon is not accessible. Start Docker Desktop or another Docker-compatible runtime before running Aspire validation.
```

This appears to be an environment issue in the current session. Earlier Aspire migration validation succeeded when Docker was available, and the unchanged smoke test passed at that time.

## Remaining limitations

- The validation script depends on Docker being installed, running, and accessible from the current shell.
- The validation script assumes the AppHost can bind `localhost:8080` and `localhost:3000`.
- The script uses the Compose-compatible demo password `demo` for local validation only.
- On Windows, Git Bash is preferred. If Git Bash is not installed and `bash` resolves to WSL, `localhost` may not reach Windows-hosted Aspire endpoints.
- The script validates the same coverage as `tests/smoke.sh`; it does not add direct worker heartbeat assertions.
- The repository still does not include `global.json`, so SDK selection depends on the developer's installed SDKs.

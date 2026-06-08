# Stage E Remote Aspire Runtime Validation Report

## Summary

Stage E validated the existing Experiment 03 Aspire migration on the Google Cloud DevBox after the Stage D Docker Compose baseline passed.

Final status: `PASS`

## Date and environment

- Validation time: 2026-06-08T18:20:00Z
- VM name: `compose-aspire-devbox-01`
- Repository commit: `b38039a66ee92f0e83f9c1b3e7c4cc9e532b4175`
- Aspire application path: `experiments/03-codex-desktop-voting-app/aspire`
- AppHost project path: `src/AppHost/AppHost.csproj`
- Target framework: `net10.0`
- Aspire package version: `13.3.5`
- .NET SDK on DevBox: `10.0.108`

Environment-specific IP addresses, dashboard login tokens, SSH fingerprints, and OS Login identity values are intentionally omitted from this Git-tracked report.

## Repository preparation

The DevBox repository clone was clean before validation and was updated safely with:

```bash
git fetch origin main
git merge --ff-only origin/main
```

The clone fast-forwarded to:

```text
b38039a66ee92f0e83f9c1b3e7c4cc9e532b4175
```

No tracked DevBox work was overwritten.

## Prerequisite validation

The DevBox prerequisite check passed before Aspire validation:

```text
PASS=14 WARN=1 FAIL=0
```

The only warning was that optional Chrome or Chromium was not installed. This was non-blocking because Stage E required only lightweight dashboard validation and no screenshot capture.

## Aspire migration inspection

The existing migration contains one Aspire AppHost project:

```text
experiments/03-codex-desktop-voting-app/aspire/src/AppHost/AppHost.csproj
```

Project characteristics:

- target framework: `net10.0`;
- AppHost SDK: `Aspire.AppHost.Sdk` `13.3.5`;
- package references: `Aspire.Hosting.AppHost`, `Aspire.Hosting.PostgreSQL`, and `Aspire.Hosting.Redis` `13.3.5`;
- launch profile: `http`;
- dashboard application URL: `http://localhost:15396`;
- required runtime parameter: `Parameters__postgres-password`.

The runtime parameter was supplied with:

```bash
export Parameters__postgres-password='<redacted-development-value>'
```

The development value used during validation is intentionally omitted from Git-tracked artifacts.

No migration source changes were required.

## Build result

Command:

```bash
cd experiments/03-codex-desktop-voting-app/aspire
dotnet build
```

Result:

```text
Build succeeded.
0 Warning(s)
0 Error(s)
```

Restore also completed successfully during the build.

Build result: `PASS`

## Runtime startup result

Command:

```bash
Parameters__postgres-password='<redacted-development-value>' \
dotnet run --project src/AppHost/AppHost.csproj --no-build --launch-profile http
```

The AppHost started successfully and emitted the dashboard URL. The dashboard login token is intentionally omitted from this report.

Startup output confirmed:

- Aspire version `13.3.5`;
- AppHost directory resolved correctly;
- dashboard listening on `http://localhost:15396`;
- distributed application started.

Non-blocking development warnings:

- no trusted Aspire development certificate was found;
- a local ASP.NET Core Data Protection key may be persisted without encryption.

Runtime startup result: `PASS`

## Docker and Aspire resource result

The expected resources started:

| Resource | Result |
| --- | --- |
| `db` | started |
| `redis` | started |
| `vote` | started |
| `worker` | started |
| `result` | started |

Application logs showed:

- PostgreSQL initialized and became ready;
- Redis started and accepted connections;
- `vote` served HTTP traffic;
- `worker` connected to Redis and processed the submitted test vote;
- `result` connected to PostgreSQL and served the result page.

Resource startup result: `PASS`

## Endpoint validation

Commands:

```bash
curl -sS -o /dev/null -w 'vote_status=%{http_code}\n' http://localhost:8080
curl -sS -o /dev/null -w 'result_status=%{http_code}\n' http://localhost:8081
curl -sS http://localhost:8080 | head
curl -sS http://localhost:8081 | head
```

Results:

```text
vote_status=200
result_status=200
```

Both pages returned the expected Cats vs Dogs HTML content.

Endpoint validation result: `PASS`

## Smoke test result

The existing Experiment 03 smoke test was run against the Aspire runtime without changing the test file.

The test still calls `curl.exe`, so Stage E reused the temporary Linux runtime shim approach from Stage D:

```bash
mkdir -p /tmp/stage-e-bin
ln -sf /usr/bin/curl /tmp/stage-e-bin/curl.exe
cd experiments/03-codex-desktop-voting-app
env PATH=/tmp/stage-e-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  VOTE_URL=http://localhost:8080 \
  RESULT_URL=http://localhost:8081 \
  bash ./tests/smoke.sh
```

The Compose-specific container assertions were skipped by leaving `COMPOSE_DIR` unset. Endpoint and functional assertions were unchanged.

Passed checks:

- vote endpoint responded;
- result endpoint responded;
- vote page contained expected voting text;
- result page contained expected result text;
- a vote was submitted;
- the result endpoint remained readable after the vote.

Smoke test result: `PASS`

## Dashboard validation

Lightweight dashboard validation was performed without installing browser tooling.

Evidence:

- AppHost emitted the dashboard URL;
- dashboard base URL responded with HTTP `302` to the login flow;
- expected resources were running while the AppHost was active;
- application and container logs were inspectable through the runtime.

No Chrome or Chromium installation was required.

Dashboard validation result: `PASS`

## Observability classification

Trace and metric availability was not required for Stage E PASS.

The source application does not include explicit OpenTelemetry instrumentation outside vendored frontend code. Missing traces or metrics should therefore be classified as:

```text
OBSERVABILITY_LIMITATION
```

This is not a migration failure.

## Cleanup result

The AppHost was stopped after validation.

Cleanup notes:

- the initial `SIGINT` signal did not stop the detached background AppHost process;
- `SIGTERM` stopped the Stage E AppHost process and its DCP child processes;
- Aspire-created containers were removed by the AppHost shutdown;
- no unrelated containers, images, or volumes were deleted;
- the temporary `/tmp/stage-e-bin/curl.exe` shim was removed.

Final Docker inspection showed no remaining containers.

Cleanup result: `PASS`

## Evidence retention

Raw AppHost evidence was retained on the DevBox outside the Git clone in a timestamped Stage E evidence directory.

Raw evidence is not committed because runtime logs may include dashboard login tokens and environment-specific values.

## Issues and follow-up

| Issue | Classification | Follow-up |
| --- | --- | --- |
| Optional Chrome or Chromium is not installed. | Non-blocking tooling gap | Install only if a future stage requires dashboard screenshots or browser automation. |
| AppHost emitted development certificate and local Data Protection warnings. | Expected development environment warning | Do not treat as production readiness. |
| Existing smoke test calls `curl.exe`. | Cross-platform test portability issue | Consider platform-neutral curl selection in a separate focused change. |
| Existing smoke test has Compose-specific container assertions. | Test portability limitation | Leave `COMPOSE_DIR` unset for Aspire runtime smoke tests, or add a separate Aspire resource assertion path in a future focused change. |
| Source application does not emit explicit OpenTelemetry traces or metrics. | `OBSERVABILITY_LIMITATION` | Do not score missing traces or metrics as a migration failure. |

## Final Stage E status

`PASS`

The existing Experiment 03 Aspire migration builds on the DevBox, starts successfully, creates the expected resources, exposes the vote and result endpoints, passes the existing functional smoke test against Aspire endpoints, provides lightweight dashboard evidence, and cleans up after validation.

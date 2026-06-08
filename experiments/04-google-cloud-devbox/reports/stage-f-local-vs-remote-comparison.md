# Stage F Local versus Remote Execution Comparison

## Summary

Stage F compares the Experiment 03 Codex Desktop execution with the Experiment 04 Google Cloud DevBox execution of the same Docker Example Voting App and the same completed Aspire migration.

Final Stage F status: `PASS`

Primary conclusion:

> The Experiment 03 Aspire migration is reproducible on the remote Ubuntu DevBox. The DevBox is better suited than the local Windows desktop for repeatable autonomous build and runtime validation, while the local desktop produced deeper visual dashboard evidence because browser tooling was available through a fallback.

This comparison does not treat the number of execution attempts as a direct environment benchmark. Experiment 03 included migration implementation and iterative fixes. Experiment 04 Stage E validated the already completed migration without changing Aspire code.

## Evidence sources

Local Experiment 03 evidence:

- `experiments/03-codex-desktop-voting-app/AI/baseline-compose-validation-report.md`
- `experiments/03-codex-desktop-voting-app/AI/aspire-runtime-validation-report.md`
- `experiments/03-codex-desktop-voting-app/AI/aspire-dashboard-validation-report.md`
- `experiments/03-codex-desktop-voting-app/AI/functional-equivalence-review.md`
- `experiments/03-codex-desktop-voting-app/AI/final-assessment.md`
- `experiments/03-codex-desktop-voting-app/AI/session-iteration-log.md`

Remote Experiment 04 evidence:

- `experiments/04-google-cloud-devbox/reports/stage-c-devbox-validation-report.md`
- `experiments/04-google-cloud-devbox/reports/stage-d-remote-compose-baseline-report.md`
- `experiments/04-google-cloud-devbox/reports/stage-e-remote-aspire-runtime-report.md`

## Environment comparison

| Area | Local Codex Desktop | Remote Google Cloud DevBox | Assessment |
| --- | --- | --- | --- |
| Operating system | Windows desktop | Ubuntu 24.04 LTS | Linux is closer to the container runtime model and reduces Windows shell and named-pipe dependencies. |
| Docker | Docker Desktop `28.5.1` | Docker Engine `29.5.3` | Both passed. The DevBox daemon was directly available to the non-root user and was easier to validate consistently. |
| Compose CLI | `docker-compose` compatibility command | `docker compose` plugin `v5.1.4` | Remote execution used the current plugin command without a compatibility fallback. |
| .NET SDK | .NET `10.0.300` | .NET `10.0.108` | Both built the final `net10.0` AppHost with Aspire `13.3.5`. |
| Bash execution | Required explicit Git Bash; WSL bash was unusable | Native Bash `5.2.21` | Remote Linux provides a more predictable shell environment. |
| Browser tooling | Browser plugins failed; headless Chrome/CDP fallback succeeded | Chrome/Chromium not installed | Local execution produced stronger visual dashboard evidence. Remote browser absence was non-blocking for runtime validation. |
| Runtime isolation | Shared workstation state and sandbox permissions | Dedicated reusable VM | DevBox execution is less coupled to desktop session and local tool state. |

## Validation result comparison

| Validation area | Local Experiment 03 | Remote Experiment 04 | Comparison |
| --- | --- | --- | --- |
| Docker Compose baseline | `PASS` | `PASS` | Both built all application images, started five default services, exposed endpoints, and passed the same smoke workflow. |
| Aspire build | Final `PASS`, `0` warnings and `0` errors | `PASS`, `0` warnings and `0` errors | The completed migration reproduced cleanly on the DevBox. |
| Aspire AppHost startup | Final `PASS` after iterative migration fixes | `PASS` without Aspire code changes | Remote startup confirms the final AppHost is portable to Ubuntu. |
| Aspire resources | All five expected resources running | All five expected resources running | Resource topology reproduced successfully. |
| Vote endpoint | HTTP workflow passed on port `8080` | HTTP `200` on port `8080` | Equivalent. |
| Result endpoint | HTTP workflow passed on port `8081` | HTTP `200` on port `8081` | Equivalent. |
| Functional smoke test | `PASS` | `PASS` | Both submitted a vote and confirmed that the result endpoint remained readable. |
| Dashboard resources | Five resources confirmed through dashboard screenshots | Five resources confirmed through AppHost output, Docker inspection, and lightweight dashboard HTTP validation | Remote evidence is sufficient for Stage E but less visually complete. |
| Console logs | Visible in dashboard and captured by screenshot | Inspected through AppHost and container logs | Both provided operational log evidence. |
| Traces, metrics, and structured logs | Not available | Not required and not available from the source containers | Same upstream observability limitation; not a migration failure. |
| Cleanup | Compose and Aspire runtimes stopped | Compose and Aspire runtimes stopped; final Docker inspection showed no containers | Both completed cleanup. |

## Docker Compose baseline comparison

Both environments proved the original Compose application works:

- `vote`, `result`, `worker`, `redis`, and `db` started;
- vote and result endpoints were reachable;
- the smoke test validated page content and the basic vote flow;
- cleanup completed without deleting the retained PostgreSQL volume.

The local desktop baseline started without a documented healthcheck permission correction.

The remote Linux baseline initially failed because `source/healthchecks/redis.sh` and `source/healthchecks/postgres.sh` were not executable in the Git checkout. A runtime-only `chmod +x` correction allowed the baseline to pass, and the original working-tree state was restored afterward.

Classification:

```text
SOURCE_LIMITATION
```

The executable-bit issue is a source portability defect exposed by Linux. It is not an Aspire migration failure and does not invalidate the successful remote baseline after the documented runtime-only correction.

## Aspire build and runtime comparison

The final Experiment 03 AppHost uses:

- target framework `net10.0`;
- Aspire `13.3.5`;
- native Aspire PostgreSQL and Redis resources;
- Dockerfile resources for `vote`, `worker`, and `result`;
- fixed public HTTP ports `8080` and `8081`;
- an externally supplied PostgreSQL password parameter.

The local migration required iterative implementation fixes before reaching its final passing state:

- adding the Aspire AppHost SDK;
- adding explicit launch profile values;
- upgrading Aspire packages for .NET 10 compatibility;
- restoring Compose-equivalent no-auth Redis behavior;
- removing an unnecessary PostgreSQL child database resource.

The remote DevBox built and ran that completed migration without Aspire code changes. This is direct evidence that the final migration is reproducible outside the original Codex Desktop environment.

## Endpoint and smoke-test comparison

Both environments preserved the same externally observable workflow:

- vote endpoint on `localhost:8080`;
- result endpoint on `localhost:8081`;
- expected Cats vs Dogs page content;
- successful vote submission;
- readable result endpoint after worker processing.

The existing smoke test introduced environment-specific command handling:

- local Windows execution required explicit Git Bash;
- non-login Git Bash initially lacked `mktemp`, so the final local run used a login shell;
- remote Linux execution required a temporary `curl.exe` shim because the test hardcodes the Windows command name;
- remote Compose execution also explicitly selected the `docker compose` command.

Classification:

```text
SOURCE_LIMITATION
```

The smoke test is functionally reusable but not command-portable. This is test portability debt, not a migration failure.

## Dashboard and observability comparison

Local dashboard validation was deeper:

- the resources page was captured;
- console logs were captured;
- structured logs, traces, and metrics pages were inspected;
- screenshots were retained.

The local Browser and Chrome plugin paths failed during Windows sandbox bootstrap. Headless Chrome with CDP provided the successful fallback.

Remote dashboard validation was intentionally lightweight:

- AppHost emitted the dashboard URL;
- the dashboard base URL responded to the login flow;
- expected resources were confirmed through Docker and AppHost evidence;
- AppHost and container logs were inspected;
- Chrome or Chromium was not installed.

The source containers do not emit explicit OpenTelemetry traces, metrics, or structured logs. The missing signals are classified consistently in both environments as:

```text
OBSERVABILITY_LIMITATION
```

They are not migration failures.

## Issue classification

| Finding | Classification | Environment |
| --- | --- | --- |
| Windows required explicit Git Bash and could not use the available WSL bash path. | `ENVIRONMENT_FAILURE` during unsuccessful attempts; resolved with approved local tooling | Local |
| Docker Desktop command and sandbox access required compatibility handling or escalation. | `ENVIRONMENT_FAILURE` during unsuccessful attempts; resolved for final validation | Local |
| Local browser plugins failed during Windows sandbox bootstrap. | `ENVIRONMENT_FAILURE`; headless Chrome/CDP fallback succeeded | Local |
| Aspire `9.0.0` dashboard did not render correctly with the installed .NET 10 environment. | `ENVIRONMENT_FAILURE` / version compatibility issue discovered during migration implementation | Local |
| Linux Compose healthcheck scripts lacked executable permissions. | `SOURCE_LIMITATION` | Remote |
| Smoke test hardcodes `curl.exe`. | `SOURCE_LIMITATION` | Remote exposure of cross-platform test debt |
| Optional Chrome or Chromium is not installed. | Non-blocking environment limitation | Remote |
| Detached AppHost did not stop on the first `SIGINT`; targeted `SIGTERM` completed cleanup. | Non-blocking operational issue | Remote |
| No source-container traces, metrics, or structured logs. | `OBSERVABILITY_LIMITATION` | Both |
| Redis is intentionally unauthenticated to preserve demo Compose behavior. | `DOCUMENTED_DIFFERENCE` and non-production source configuration | Both |

No validated finding is classified as `MIGRATION_FAILURE`.

## Evidence quality comparison

### Local evidence strengths

- detailed iteration log;
- dashboard screenshots for resources, console logs, structured logs, traces, and metrics;
- migration design and functional-equivalence review;
- documented fixes applied while creating the migration.

### Local evidence limitations

- execution evidence is coupled to the migration-development session;
- several failures came from Windows sandbox, Docker Desktop, shell, and browser bootstrap behavior;
- historical local reports include development credential-like values and an ephemeral dashboard login token. Those existing values are not repeated in this report and should be removed or redacted in a separate security-focused cleanup.

### Remote evidence strengths

- clear stage separation for environment readiness, Compose baseline, and Aspire runtime;
- explicit repository commit recording;
- repeatable prerequisite output;
- raw runtime evidence retained outside Git;
- tracked reports intentionally omit dashboard login tokens, IP addresses, and runtime credential values;
- final clean repository and runtime cleanup checks.

### Remote evidence limitations

- no dashboard screenshots;
- no quantitative timing or performance benchmark;
- raw evidence remains only on the DevBox and is not indexed in the tracked report set.

Overall evidence assessment:

> Remote evidence is stronger for repeatable runtime validation and security-conscious evidence handling. Local evidence is stronger for visual dashboard inspection and migration-development history.

## Execution reliability and cost considerations

The DevBox provided a stable, dedicated Linux execution environment with direct non-root Docker access and a compatible .NET SDK. After Stage C setup, both the Compose baseline and completed Aspire migration passed.

The local desktop also completed the workflow, but successful execution depended more heavily on workstation-specific state:

- Docker Desktop availability and context access;
- Git Bash selection;
- sandbox escalation;
- browser fallback behavior.

No controlled timing, latency, or performance benchmark was collected, so this comparison does not claim that one environment executes builds or requests faster.

The DevBox introduces ongoing Google Compute Engine cost while running and additional SSH/startup overhead. Cost suitability depends on stopping or deleting the VM when it is not needed. The dedicated environment benefit is operational repeatability, not demonstrated performance or cost reduction.

## DevBox suitability

DevBox suitability for future autonomous Compose-to-Aspire validation: `PASS`

The DevBox is better suited for:

- repeatable Docker and Aspire runtime validation;
- Linux portability testing;
- long-running or unattended validation;
- separating runtime evidence from local workstation state;
- consistent non-root Docker execution;
- security-conscious evidence retention outside Git.

Codex Desktop remains useful for:

- interactive migration implementation;
- direct inspection of local artifacts;
- richer dashboard screenshot capture when browser tooling works;
- rapid iteration that depends on desktop applications.

Recommended operating model:

1. Implement or review migrations in the most productive development environment.
2. Treat the DevBox as the independent reproducibility and runtime-validation environment.
3. Keep the same functional smoke workflow across both environments.
4. Fix cross-platform source and test portability issues separately from migration logic.
5. Add source OpenTelemetry instrumentation only as a separate observability scope.

## Conclusions

### Is the Experiment 03 Aspire migration reproducible on the DevBox?

Yes.

The unchanged completed migration built cleanly, started all expected resources, exposed the expected endpoints, passed the same functional smoke workflow, and cleaned up successfully on the remote Ubuntu DevBox.

### Is remote Linux execution better suited for autonomous validation than local desktop execution?

Yes, for repeatable autonomous build and runtime validation.

The dedicated Linux environment reduced dependence on Windows shell selection, Docker Desktop state, browser bootstrap, and desktop session lifetime. Local execution remains stronger for interactive development and detailed visual dashboard inspection.

### Which findings are migration failures?

None of the validated Stage F findings are migration failures.

The remaining findings are:

- local or remote environment limitations;
- source and smoke-test portability limitations;
- documented operational differences;
- source observability limitations.

## Final Stage F status

`PASS`

The comparison is complete, the Experiment 03 migration is confirmed reproducible on the DevBox, and the DevBox is suitable as an independent remote runtime-validation environment.

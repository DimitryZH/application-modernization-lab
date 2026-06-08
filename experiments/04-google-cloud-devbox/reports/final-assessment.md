# Experiment 04 Final Assessment

## Executive Summary

Experiment 04 evaluated whether a completed Docker Compose to .NET Aspire migration can be validated reliably on a remote Google Cloud DevBox.

The experiment defined a validation methodology, provisioned and prepared a Google Compute Engine development VM, validated the original Docker Compose baseline, validated the existing Experiment 03 Aspire migration, and compared remote execution with the original local Codex Desktop run.

Stages A through F completed successfully. The original Compose deployment and the completed Aspire migration both passed endpoint and functional smoke validation on the DevBox. The Aspire migration required no code changes for remote execution.

Experiment 04 result: `PASS`

Final score: `95 / 100`

## Research Question

> Can a completed Compose-to-Aspire migration be validated reliably on a remote Google Cloud DevBox?

Yes.

The unchanged Experiment 03 Aspire migration restored and built cleanly on the Ubuntu DevBox, started the expected resources, exposed the expected endpoints, passed the existing functional smoke workflow, and cleaned up successfully. The remote run also reproduced the original Compose baseline before validating Aspire behavior.

The DevBox therefore provides a reliable independent environment for repeatable Compose-to-Aspire runtime validation.

## Stage Results

| Stage | Result | Summary |
| --- | --- | --- |
| A | `PASS` | Defined the research methodology, success criteria, scoring model, and execution roadmap before provisioning. |
| B | `PASS` | Created the Google Cloud DevBox, recorded its configuration, and verified SSH access. |
| C | `PASS` | Installed and validated Docker, Docker Compose, .NET, and supporting tools; prerequisite check completed with no blocking failures. |
| D | `PASS` | Built and started the original Compose application, validated endpoints, passed the smoke workflow, captured evidence, and cleaned up. |
| E | `PASS` | Built and started the existing Aspire migration without source changes, validated resources and endpoints, passed the smoke workflow, and cleaned up. |
| F | `PASS` | Confirmed remote reproducibility, separated environment and source limitations from migration failures, and assessed DevBox suitability. |

## Scoring

| Category | Score |
| --- | ---: |
| Compose Validation | 20 / 20 |
| Migration Quality | 20 / 20 |
| Aspire Build | 15 / 15 |
| Aspire Runtime | 20 / 20 |
| Functional Equivalence | 15 / 15 |
| Dashboard Validation | 5 / 10 |
| **Total Score** | **95 / 100** |

Score band result: `PASS`

No result cap applies. The Compose baseline, Aspire build, Aspire runtime, smoke tests, and supporting evidence all passed.

### Compose Validation: 20 / 20

| Criterion | Score | Justification |
| --- | ---: | --- |
| Source version and Compose topology recorded | 4 / 4 | The source application, repository commit, five-service topology, ports, networks, volume, and dependencies were documented. |
| Images build or pull successfully | 4 / 4 | Application images built and PostgreSQL and Redis images pulled successfully. |
| Services start successfully | 4 / 4 | All five default services started after a documented runtime-only correction for source healthcheck file permissions. |
| Expected endpoints are reachable | 4 / 4 | Vote and result endpoints returned HTTP `200`. |
| Smoke tests pass and logs are captured | 4 / 4 | The unchanged functional workflow passed and relevant logs were retained as raw DevBox evidence. |

### Migration Quality: 20 / 20

| Criterion | Score | Justification |
| --- | ---: | --- |
| All Compose services mapped or explicitly justified | 5 / 5 | The five default services were mapped; the profile-gated seed service was explicitly excluded from default startup. |
| Ports, environment variables, dependencies, and startup ordering preserved | 5 / 5 | Public ports, service relationships, required names, persistence, and startup waits were preserved or deliberately improved without changing user-visible behavior. |
| Aspire-native resources used where appropriate | 4 / 4 | PostgreSQL and Redis use Aspire-native resources; custom services use Dockerfile resources. |
| Secrets are not hardcoded and configuration is maintainable | 3 / 3 | The AppHost uses an externally supplied secret parameter for the PostgreSQL password. No new runtime secret value was committed during Experiment 04. |
| Migration report documents topology, rationale, and differences | 3 / 3 | Existing migration design and equivalence evidence document topology, rationale, risks, and known differences. |

### Aspire Build: 15 / 15

| Criterion | Score | Justification |
| --- | ---: | --- |
| Dependency restore succeeds | 4 / 4 | Restore completed successfully during the remote build. |
| `dotnet build` succeeds | 7 / 7 | The `net10.0` AppHost built successfully. |
| Configuration is valid for local DevBox execution | 2 / 2 | The existing launch profile and runtime parameter allowed the AppHost to start on the DevBox without source changes. |
| Build warnings resolved or documented | 2 / 2 | The final remote build completed with zero warnings and zero errors. |

### Aspire Runtime: 20 / 20

| Criterion | Score | Justification |
| --- | ---: | --- |
| AppHost starts successfully | 5 / 5 | Aspire `13.3.5` started and emitted the dashboard URL. |
| Required resources start successfully | 5 / 5 | PostgreSQL, Redis, vote, worker, and result started. |
| Expected endpoints are reachable | 4 / 4 | Vote and result endpoints returned HTTP `200` and expected page content. |
| Smoke tests pass | 4 / 4 | The existing functional smoke workflow passed against the Aspire endpoints. |
| Runtime logs are captured | 2 / 2 | AppHost and container logs were inspected and raw evidence was retained outside Git. |

### Functional Equivalence: 15 / 15

| Criterion | Score | Justification |
| --- | ---: | --- |
| User-visible workflow preserved | 6 / 6 | Vote submission and result readability were preserved. |
| Compose and Aspire smoke tests cover the same behavior | 4 / 4 | The same test file and functional assertions were used for both deployments. |
| Data flow and service interactions remain equivalent | 3 / 3 | The worker processed the submitted vote through Redis and PostgreSQL, and the result service remained readable. |
| Known differences documented and justified | 2 / 2 | Operational, startup-ordering, persistence-name, and observability differences are documented. |

### Dashboard Validation: 5 / 10

| Criterion | Score | Justification |
| --- | ---: | --- |
| Aspire dashboard is accessible | 3 / 3 | AppHost emitted the dashboard URL and the dashboard base URL responded to the login flow. |
| Expected resources are visible | 0 / 3 | The expected resources were confirmed through AppHost and Docker evidence, but no direct remote dashboard resource-view evidence was collected. |
| Console logs are visible for relevant resources | 0 / 2 | Logs were inspected through AppHost and Docker, but no direct remote dashboard console-view evidence was collected. |
| Trace and metric availability inspected and classified | 2 / 2 | Missing source-container telemetry was inspected and correctly classified as an observability limitation. |

The lightweight Stage E dashboard check met the stage-specific runtime validation goal. The official scoring model requires direct dashboard-view evidence for the resource and console-log points, so those points are not awarded.

## Classification Summary

### `MIGRATION_FAILURE`

None observed.

The completed Aspire migration built and ran remotely without source changes, and the functional smoke workflow passed.

### `ENVIRONMENT_FAILURE`

None blocked the final remote validation.

Resolved or non-blocking environment findings:

- required DevBox tooling was initially absent and was installed during Stage C;
- optional Chrome or Chromium was not installed, limiting dashboard evidence depth;
- the detached AppHost did not stop on the first `SIGINT`, but targeted `SIGTERM` completed cleanup;
- the VM uses the default VPC and an ephemeral external IPv4 address, which are development-environment risks rather than validation failures.

### `SOURCE_LIMITATION`

- Compose healthcheck scripts lacked executable permissions in the Linux Git checkout and required a runtime-only permission correction.
- The existing smoke test invokes `curl.exe`, requiring a temporary command shim on Linux.
- The upstream development configuration includes unauthenticated Redis, development server behavior, and transient startup messages.

### `OBSERVABILITY_LIMITATION`

- The source containers do not emit explicit OpenTelemetry traces, metrics, or structured logs.
- Missing source telemetry did not affect build, runtime, endpoint, or functional equivalence validation.

### `DOCUMENTED_DIFFERENCE`

- Aspire uses the vote Dockerfile final stage rather than the Compose development target and source bind mount.
- Aspire adds a result-to-worker startup wait to reduce the upstream database table race.
- Aspire uses an experiment-specific PostgreSQL data volume name.
- Redis remains unauthenticated to preserve the upstream demo behavior; this is not production-safe.
- Remote dashboard validation was intentionally lightweight and did not include screenshots or direct resource and console-log views.

## Key Findings

### What worked well

- A dedicated Ubuntu VM provided predictable native Bash, Docker Engine, Docker Compose, and .NET execution.
- The original Compose baseline and the completed Aspire migration both passed on the same remote host.
- The final Aspire migration required no remote source changes.
- The same functional smoke workflow validated Compose and Aspire behavior.
- Stage separation produced clear evidence for environment readiness, baseline behavior, Aspire runtime behavior, and local-versus-remote comparison.
- Runtime-sensitive evidence was retained outside Git while tracked reports omitted runtime secret values, dashboard login tokens, and assigned IP addresses.

### What failed or required correction

- The first VM creation command required the compatible `--no-scopes` option when no service account was attached.
- Required runtime tools were not present initially and had to be installed.
- Linux exposed missing executable permissions on the source healthcheck scripts.
- The smoke test's `curl.exe` command was not portable to Linux without a temporary shim.
- The first AppHost shutdown signal did not stop the detached process; a targeted termination signal completed cleanup.
- Direct dashboard resource and console-log evidence was not collected remotely.

### What surprised the experiment

- The completed Aspire migration was portable from Windows Desktop to Ubuntu without Aspire code changes.
- Linux exposed source and test portability issues that did not block the original Windows run.
- The most significant remote limitations were evidence depth and source portability, not migration correctness.
- A lightweight dashboard check was sufficient for runtime validation but not sufficient for full dashboard scoring.

### What was learned

- A remote Linux DevBox is an effective independent reproducibility gate for Compose-to-Aspire migrations.
- Functional equivalence should be established with the same smoke workflow before evaluating observability depth.
- Source portability problems must be classified separately from migration failures.
- Raw runtime evidence should remain outside Git unless it is sanitized.
- Direct dashboard screenshots or structured dashboard exports should be planned when full dashboard scoring is required.

## DevBox Assessment

Final DevBox suitability rating: `PASS`

### Repeatability

The DevBox supported explicit prerequisite checks, recorded tool versions, repository commit tracking, repeatable Compose and Aspire commands, and staged evidence collection.

### Reliability

After Stage C setup, both Compose and Aspire validations completed successfully. Native Linux execution reduced dependence on Docker Desktop, WSL selection, and local workstation session state.

### Operational overhead

The DevBox requires:

- VM creation or startup;
- SSH-based execution;
- initial tool installation and maintenance;
- explicit evidence retention and cleanup;
- cost management while the VM or persistent disk exists.

This overhead is acceptable for independent validation but is higher than a single local development run.

### Suitability for autonomous validation

The DevBox is well suited for repeatable and longer-running autonomous validation because it provides a dedicated execution environment with direct non-root Docker access and predictable Linux tooling.

### Suitability for future experiments

The DevBox is suitable as a reusable validation environment for future migrations, provided each run:

- records the repository revision;
- verifies prerequisites;
- keeps secrets and raw runtime values outside Git;
- performs explicit cleanup;
- stops or deletes unused cloud resources;
- captures direct dashboard evidence when full dashboard scoring is required.

## Comparison Outcome

### Local Desktop

Strengths:

- productive interactive migration implementation;
- deeper visual dashboard inspection through a browser fallback;
- detailed migration-development history.

Limitations:

- greater dependence on Docker Desktop state, Windows shell selection, sandbox permissions, and browser bootstrap behavior.

### Remote DevBox

Strengths:

- independent Linux portability validation;
- predictable native Bash and Docker execution;
- stable runtime environment separated from workstation state;
- strong staged runtime evidence and cleanup discipline.

Limitations:

- cloud cost and operational lifecycle management;
- SSH and setup overhead;
- no direct dashboard screenshots or remote UI-level resource and console-log evidence in this run.

Conclusion:

> Use the most productive environment for migration implementation, then use the DevBox as the independent reproducibility and runtime-validation gate.

## Recommendations

### Immediate recommendations

1. Stop the DevBox when it is not actively used to avoid unnecessary compute charges.
2. Preserve the Stage B through Stage G reports as the evidence set for Experiment 04.
3. Keep raw AppHost and container evidence outside Git unless it is sanitized.
4. Treat the current VM as development-only infrastructure.

### Future experiment recommendations

1. Fix source healthcheck executable permissions or invoke the scripts through an explicit shell before the next Linux baseline run.
2. Make the smoke test select a platform-appropriate curl command without weakening functional assertions.
3. Capture direct dashboard resource and console-log evidence when full dashboard scoring is required.
4. Record build, startup, and smoke-test durations if future comparisons need quantitative reliability or performance analysis.
5. Continue using the same smoke workflow for Compose and Aspire validation.

### Future platform recommendations

1. Replace broad default-network exposure with a tighter access model before treating the DevBox pattern as a reusable platform standard.
2. Prefer private access or IAP-based SSH for future hardened DevBox iterations.
3. Automate prerequisite installation only after the manual workflow remains stable across additional experiments.
4. Add a repeatable evidence index that references sanitized tracked reports and protected raw evidence.
5. Introduce source OpenTelemetry instrumentation only as a separate observability experiment, not as a migration-correctness requirement.

## Evidence Index

Primary Experiment 04 evidence:

- `reports/stage-b-devbox-creation-report.md`
- `reports/stage-c-devbox-validation-report.md`
- `reports/stage-d-remote-compose-baseline-report.md`
- `reports/stage-e-remote-aspire-runtime-report.md`
- `reports/stage-f-local-vs-remote-comparison.md`

Methodology and evaluation criteria:

- `docs/migration-validation-plan.md`
- `docs/success-criteria.md`
- `docs/scoring-model.md`
- `docs/experiment-04-roadmap.md`

## Final Verdict

```text
Experiment 04 Result:
PASS

Final Score:
95 / 100
```

Experiment 04 demonstrated that a completed Compose-to-Aspire migration can be validated reliably on a remote Google Cloud DevBox. The original Compose baseline and the unchanged Aspire migration both passed functional validation. The five unawarded points reflect missing direct remote dashboard resource and console-log evidence, not a migration or runtime failure.

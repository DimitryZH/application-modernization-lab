# Success Criteria

## Purpose

This document defines the PASS criteria for future Experiment 04 remote migration validation runs.

The DevBox setup alone is not a successful migration. A successful run must demonstrate that the original Docker Compose application works, that the Aspire migration builds and runs, and that the user-visible workflow is preserved.

## DevBox Readiness

PASS:

- the VM is reachable through SSH;
- required tools are installed;
- `check-devbox-prereqs.sh` reports no blocking failures;
- Docker can be used by the non-root validation user;
- enough disk space remains for Docker images, NuGet packages, logs, and build artifacts.

FAIL:

- SSH access is unavailable;
- Docker cannot run containers;
- .NET SDK is unavailable;
- the environment cannot run the selected validation workflow.

## Source Baseline

PASS:

- source repository URL is recorded;
- source version is pinned by commit SHA, tag, or equivalent immutable reference;
- Compose files and service topology are documented;
- source limitations are recorded before migration changes.

FAIL:

- source version is unknown;
- Compose topology is not inspected before migration;
- baseline limitations are discovered only after migration and cannot be separated from migration changes.

## Compose Validation

PASS:

- required images build successfully or pull successfully;
- services start;
- expected endpoints are reachable;
- smoke tests pass;
- logs and container status are captured.

PARTIAL:

- services start but non-critical checks require documented manual adjustment;
- a source application limitation is found and documented before migration.

FAIL:

- the baseline application cannot start;
- smoke tests fail for the original Compose version;
- baseline evidence is missing.

## Migration Quality

PASS:

- Compose services are mapped to Aspire resources;
- ports, environment variables, dependencies, startup order, and persistent data requirements are preserved where applicable;
- Aspire-native resources are used where appropriate;
- `WithReference` is used for service relationships;
- `WaitFor` is used for startup ordering;
- no secrets are hardcoded;
- differences from Compose are documented.

FAIL:

- a service is omitted without justification;
- required configuration is hardcoded incorrectly;
- secrets are committed;
- major behavior changes are introduced without documentation.

## Aspire Build

PASS:

- dependency restore succeeds;
- `dotnet build` succeeds;
- no blocking build or configuration errors remain.

PARTIAL:

- build succeeds with warnings that are documented and do not block runtime validation.

FAIL:

- dependency restore fails;
- build fails;
- configuration prevents the AppHost from starting.

## Aspire Runtime

PASS:

- AppHost starts;
- required resources start;
- expected endpoints are reachable;
- smoke tests pass;
- relevant runtime logs are captured.

PARTIAL:

- runtime starts and core smoke tests pass, but non-critical operational differences are documented.

FAIL:

- AppHost fails to start;
- required resources fail to start;
- expected endpoints are unreachable;
- smoke tests fail.

## Functional Equivalence

PASS:

- the user-visible workflow from the Compose baseline is preserved;
- endpoint behavior remains consistent with the baseline;
- smoke tests validate the same functional coverage for Compose and Aspire.

PARTIAL:

- core behavior is preserved, but a documented non-critical difference remains.

FAIL:

- a user-visible workflow regresses;
- smoke tests are weakened to hide migration failures;
- Aspire behavior cannot be compared to the Compose baseline.

## Dashboard Validation

PASS:

- Aspire dashboard is accessible through the approved access model;
- expected resources are visible;
- console logs are visible for relevant resources;
- traces and metrics are inspected when available;
- missing telemetry is classified correctly.

PARTIAL:

- dashboard and resources are visible, but some observability signals are unavailable due to documented upstream application limitations.

FAIL:

- dashboard is inaccessible due to migration or AppHost configuration;
- resources are not visible;
- console logs are unavailable due to migration configuration;
- missing telemetry is incorrectly reported as a migration success or failure without evidence.

## Observability classification

Missing traces alone is not an automatic FAIL.

Missing metrics alone is not an automatic FAIL.

If the source application is not instrumented for OpenTelemetry, observability limitations should be classified separately from migration failures.

Use these classifications:

| Classification | Meaning |
| --- | --- |
| `MIGRATION_FAILURE` | The migration changed or broke expected application behavior. |
| `ENVIRONMENT_FAILURE` | The DevBox, network, dependency, or tooling environment blocked validation. |
| `SOURCE_LIMITATION` | The original application lacks behavior or instrumentation needed for a validation signal. |
| `OBSERVABILITY_LIMITATION` | Dashboard traces, metrics, or structured logs are limited because the source application does not emit the required telemetry. |
| `DOCUMENTED_DIFFERENCE` | Behavior differs from Compose but is known, justified, and does not break the validated workflow. |

## Final PASS rule

Experiment 04 should be scored as PASS only when:

- Compose validation passes;
- Aspire build passes;
- Aspire runtime validation passes;
- functional smoke tests pass for both deployments;
- evidence is collected;
- any observability gaps are correctly classified.

Do not claim functional equivalence without passing smoke test evidence for both Compose and Aspire.

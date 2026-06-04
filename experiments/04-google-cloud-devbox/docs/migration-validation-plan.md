# Migration Validation Plan

## Purpose

Experiment 04 validates whether a Docker Compose to .NET Aspire migration workflow can be executed remotely on a Google Cloud DevBox through SSH with enough evidence to compare it against local execution.

The research focus is Remote Autonomous Compose-to-Aspire Migration Validation. The DevBox is the execution environment; the migration result must still be evaluated by build results, runtime behavior, functional smoke tests, and documented evidence.

## Phase 0: DevBox preparation

Objective: create a reliable remote Linux environment before any migration work starts.

Activities:

- create or start the Google Compute Engine VM;
- connect through `gcloud compute ssh`;
- install required tooling;
- clone or update this repository;
- run `check-devbox-prereqs.sh`;
- collect initial environment evidence.

Required evidence:

- VM configuration summary;
- OS version;
- CPU, memory, and disk information;
- Git, Docker, Docker Compose, .NET SDK, curl, jq, bash, and unzip versions;
- Docker access result for the non-root validation user.

Exit criteria:

- no blocking prerequisite failures;
- enough free disk space for Docker images and build artifacts;
- Docker works without `sudo` for the validation user;
- .NET SDK is available.

## Phase 1: Source import

Objective: establish a reproducible source baseline.

Activities:

- clone the selected source repository;
- record repository URL;
- record commit SHA or release tag;
- capture relevant upstream metadata;
- identify Compose files, service definitions, build contexts, ports, environment variables, volumes, commands, health checks, and dependencies.

Required evidence:

- source repository URL;
- commit SHA or release tag;
- Compose file paths;
- source import notes;
- baseline metadata report.

Exit criteria:

- source version is recorded;
- Compose topology is understood before migration begins;
- any source retrieval limitation is documented.

## Phase 2: Docker Compose baseline validation

Objective: prove the original Compose application works before migration changes are evaluated.

Activities:

- build required images;
- start the Compose stack;
- inspect service status;
- validate exposed endpoints;
- run smoke tests;
- capture logs;
- stop and clean up the baseline stack.

Required evidence:

- build command and result;
- startup command and result;
- container status;
- endpoint check output;
- smoke test output;
- relevant logs;
- cleanup command used.

Exit criteria:

- Compose build succeeds, when build is required;
- services start successfully;
- expected endpoints are reachable;
- smoke tests pass.

## Phase 3: Compose-to-Aspire migration

Objective: implement an Aspire topology that preserves the Compose application behavior.

Activities:

- create or update the Aspire AppHost;
- map Compose services to Aspire resources;
- use Aspire-native resources where appropriate;
- preserve ports, environment variables, volumes, dependencies, startup behavior, and health assumptions;
- use `WithReference` for service relationships;
- use `WaitFor` for startup ordering;
- review the migration architecture;
- write a migration report.

Required evidence:

- changed file list;
- Compose-to-Aspire mapping table;
- topology diagram or summary;
- documented differences from Compose;
- migration rationale;
- known risk list.

Exit criteria:

- migration implementation is complete enough to build;
- resource relationships are explicit;
- known differences are documented;
- no secrets are hardcoded.

## Phase 4: Aspire build validation

Objective: prove the migrated Aspire project compiles and restores cleanly.

Activities:

- restore dependencies;
- run `dotnet build`;
- inspect build output;
- validate configuration files for obvious blocking errors.

Required evidence:

- restore result, when run separately;
- build command and result;
- build warnings or errors;
- configuration review notes.

Exit criteria:

- build succeeds;
- no blocking configuration errors remain;
- warnings are either resolved or documented.

## Phase 5: Aspire runtime validation

Objective: prove the migrated Aspire application starts and behaves correctly.

Activities:

- start the Aspire AppHost;
- verify resource startup;
- validate endpoint availability;
- run the same smoke tests used for the Compose baseline;
- capture AppHost and container logs.

Required evidence:

- AppHost startup output;
- resource status;
- endpoint check output;
- smoke test output;
- logs for failing or critical services.

Exit criteria:

- AppHost starts successfully;
- required resources start successfully;
- expected endpoints are reachable;
- smoke tests pass.

## Phase 6: Dashboard validation

Objective: validate the Aspire dashboard as an operational visibility surface while distinguishing source application limitations from migration failures.

Activities:

- confirm the dashboard is reachable from the DevBox access model;
- confirm resources are visible;
- inspect console logs;
- inspect traces and metrics if available;
- document whether missing telemetry is caused by missing source application instrumentation.

Required evidence:

- dashboard URL or access notes;
- resource visibility notes;
- console log visibility notes;
- trace and metric availability notes;
- screenshots when practical.

Exit criteria:

- dashboard is accessible;
- Aspire resources are visible;
- console logs are available for relevant resources;
- missing traces or metrics are classified correctly.

Important classification:

- Missing traces alone is not an automatic failure.
- Missing metrics alone is not an automatic failure.
- If the source application is not instrumented for OpenTelemetry, observability limitations should be classified separately from migration failures.

## Phase 7: Evidence collection

Objective: preserve enough evidence to support the final assessment.

Activities:

- run `collect-devbox-evidence.sh`;
- gather validation logs;
- gather command outputs;
- gather screenshots when available;
- record repository status;
- store artifacts under `reports/`.

Required evidence:

- timestamped DevBox evidence file;
- Compose validation logs;
- Aspire validation logs;
- smoke test output;
- dashboard evidence;
- final changed file list.

Exit criteria:

- evidence is timestamped;
- evidence is stored under the experiment report structure;
- missing evidence is documented with a reason.

## Phase 8: Final assessment

Objective: score the remote migration experiment and identify follow-up work.

Activities:

- apply the scoring model;
- compare Compose and Aspire behavior;
- classify known differences;
- classify observability limitations;
- document risks and recommendations;
- produce the final Experiment 04 assessment.

Required evidence:

- final score;
- score breakdown;
- PASS, PARTIAL_PASS, or FAIL result;
- findings;
- recommendations;
- manual follow-up items.

Exit criteria:

- the result is supported by command evidence;
- functional equivalence is claimed only if smoke tests pass for both Compose and Aspire;
- any observability limitation is separated from migration correctness.

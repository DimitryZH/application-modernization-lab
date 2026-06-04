# Experiment 04 Roadmap

## Purpose

This roadmap organizes Experiment 04 into practical stages from design refinement through final assessment.

The roadmap keeps VM provisioning separate from migration execution so each stage can be validated before moving to the next one.

## Stage A: Design refinement

Status: current stage.

Objective:

- define the research purpose;
- define validation methodology;
- define success criteria;
- define scoring;
- define the execution roadmap before provisioning a VM.

Entry criteria:

- DevBox foundation documentation exists;
- helper scripts exist;
- Google Cloud project is identified;
- VM has not been provisioned for the first run.

Exit criteria:

- migration validation plan is documented;
- success criteria are documented;
- scoring model is documented;
- roadmap is documented;
- existing documentation links to the research methodology where useful.

Deliverables:

- `migration-validation-plan.md`;
- `success-criteria.md`;
- `scoring-model.md`;
- `experiment-04-roadmap.md`.

## Stage B: Create Google Cloud DevBox

Objective:

- create the first development VM using the manual `gcloud` workflow.

Entry criteria:

- Stage A is complete;
- billing is confirmed;
- required APIs are enabled intentionally;
- local `gcloud` readiness check passes or warnings are accepted.

Exit criteria:

- VM exists in `ai-agent-host-497515`;
- VM configuration is recorded;
- SSH access works;
- no credentials or private keys are committed.

Deliverables:

- VM creation evidence;
- SSH access evidence;
- initial cost and cleanup notes for the actual VM.

## Stage C: Validate DevBox environment

Objective:

- prove the VM can support Docker Compose and Aspire validation work.

Entry criteria:

- Stage B is complete;
- required tooling installation has been attempted.

Exit criteria:

- `check-devbox-prereqs.sh` reports no blocking failures;
- Docker access works for the non-root user;
- .NET SDK is available;
- baseline evidence is collected with `collect-devbox-evidence.sh`.

Deliverables:

- prerequisite check output;
- timestamped DevBox evidence file;
- documented tooling gaps, if any.

## Stage D: Run first remote baseline validation

Objective:

- validate an original Docker Compose application on the DevBox before migration.

Entry criteria:

- Stage C is complete;
- source repository and experiment target are selected;
- source version is recorded.

Exit criteria:

- Compose build or pull succeeds;
- services start;
- expected endpoints are reachable;
- smoke tests pass;
- logs and container status are captured.

Deliverables:

- source metadata;
- Compose topology summary;
- baseline validation report;
- baseline logs.

## Stage E: Run first remote migration experiment

Objective:

- perform the first remote Compose-to-Aspire migration and validate it on the DevBox.

Entry criteria:

- Stage D is complete;
- baseline behavior is known;
- migration scope is defined.

Exit criteria:

- Aspire implementation builds;
- AppHost starts;
- required resources start;
- endpoints are reachable;
- smoke tests pass or failures are documented with evidence;
- dashboard validation is performed.

Deliverables:

- migration implementation;
- migration report;
- Aspire build evidence;
- Aspire runtime evidence;
- smoke test evidence;
- dashboard evidence.

## Stage F: Compare local versus remote execution

Objective:

- compare DevBox execution against previous local execution findings.

Entry criteria:

- Stage E has enough validation evidence;
- local Experiment 03 results are available for comparison.

Exit criteria:

- execution differences are documented;
- environment-related blockers are separated from migration defects;
- cost, latency, reliability, and evidence quality are assessed.

Deliverables:

- local versus remote comparison;
- DevBox suitability notes;
- recommendations for future remote experiments.

## Stage G: Publish Experiment 04 final assessment

Objective:

- produce the final research assessment for Experiment 04.

Entry criteria:

- Stage F is complete;
- scoring inputs are available;
- known limitations are classified.

Exit criteria:

- final score is assigned;
- result is classified as PASS, PARTIAL_PASS, or FAIL;
- findings and recommendations are documented;
- manual follow-up items are listed.

Deliverables:

- final assessment report;
- score breakdown;
- evidence index;
- follow-up backlog.

## Stage progression rules

- Do not create cloud resources before Stage A is complete.
- Do not start migration work before the Compose baseline passes or the baseline limitation is explicitly classified.
- Do not claim functional equivalence unless both Compose and Aspire smoke tests pass.
- Do not classify missing traces or metrics as migration failures without proving the source application was instrumented and the migration broke telemetry.

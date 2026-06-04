# Experiment 04: Google Cloud DevBox Foundation

## Purpose

This experiment creates the foundation for running future Docker Compose to .NET Aspire migration workflows on a dedicated Google Cloud DevBox.

The research goal is Remote Autonomous Compose-to-Aspire Migration Validation: validate whether the same migration workflow used locally can be executed remotely through SSH on a Google Compute Engine VM, with repeatable prerequisite checks, success criteria, scoring, and evidence collection.

No application migration is implemented in this experiment. This directory only contains the DevBox design, setup workflow, helper scripts, and reporting structure.

## Why introduce a Google Cloud DevBox

Experiment 03 showed that a richer local execution environment can complete the migration and validation workflow. The remaining limitation was observability: the upstream application did not emit OpenTelemetry traces, metrics, or structured logs. That is an upstream application limitation, not a migration failure.

Experiment 04 introduces a remote DevBox to evaluate a different execution model:

- keep migration execution off the local workstation;
- provide a stable Linux environment for Docker and .NET Aspire workloads;
- preserve SSH-based operational control;
- collect environment and validation evidence in a repeatable way;
- prepare for longer-running migration validation without relying on a desktop session.

## Project and baseline location

- Google Cloud project: `ai-agent-host-497515`
- Region: `us-central1`
- Zone: `us-central1-a`
- Baseline VM OS: Ubuntu LTS
- VM purpose: development-only Compose-to-Aspire migration validation

## Difference versus Browser Codex

Browser-constrained execution is useful for repository edits and static analysis, but it may not provide direct access to Docker, .NET SDKs, long-running processes, or remote infrastructure tooling.

The DevBox model keeps the repository workflow familiar while moving runtime validation to a Linux VM where Docker Compose and Aspire workloads can run directly.

## Difference versus Codex Desktop

Codex Desktop can use the local workstation more fully, but it still depends on local operating system state, installed tools, resources, and session lifetime.

The DevBox model provides a dedicated remote environment that can be started, stopped, inspected, and reused for migration experiments without coupling validation to the desktop machine.

## Directory layout

```text
experiments/04-google-cloud-devbox/
|-- README.md
|-- docs/
|   |-- architecture.md
|   |-- cost-and-cleanup-notes.md
|   |-- devbox-requirements.md
|   |-- experiment-04-roadmap.md
|   |-- gcp-setup-plan.md
|   |-- migration-validation-plan.md
|   |-- scoring-model.md
|   |-- ssh-access-model.md
|   |-- success-criteria.md
|   `-- validation-workflow.md
|-- reports/
|   `-- .gitkeep
|-- scripts/
|   |-- check-local-gcloud.sh
|   |-- check-devbox-prereqs.sh
|   |-- create-devbox-gce.sh
|   |-- connect-devbox.sh
|   `-- collect-devbox-evidence.sh
`-- terraform/
    `-- README.md
```

## Current scope

In scope:

- DevBox architecture documentation.
- Google Cloud setup plan.
- SSH access model.
- Local `gcloud` readiness check.
- Manual GCE VM creation helper.
- DevBox prerequisite check.
- Evidence collection helper.
- Cost and cleanup guidance.
- Migration validation methodology.
- Success criteria and scoring model.
- Experiment roadmap.

Out of scope:

- Docker Compose to Aspire migration implementation.
- Terraform implementation.
- Agent orchestration.
- Production deployment.
- Secret or credential management inside the repository.

## Future validation goals

Future work should use this foundation to:

1. create the DevBox;
2. install required tooling;
3. clone this repository;
4. run DevBox prerequisite checks;
5. run Docker Compose baseline validation for a selected experiment;
6. run Aspire build and runtime validation;
7. run the same smoke tests;
8. collect timestamped evidence;
9. document any differences from local execution.

Functional equivalence should only be claimed after both Compose and Aspire validations pass on the DevBox.

## Research methodology

- [Migration validation plan](docs/migration-validation-plan.md)
- [Success criteria](docs/success-criteria.md)
- [Scoring model](docs/scoring-model.md)
- [Experiment 04 roadmap](docs/experiment-04-roadmap.md)

## Quick start

From a local workstation with Google Cloud CLI installed:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/check-local-gcloud.sh
bash ./scripts/create-devbox-gce.sh
bash ./scripts/connect-devbox.sh
```

Inside the VM, after installing required tools and cloning the repository:

```bash
cd compose-to-aspire-demo/experiments/04-google-cloud-devbox
bash ./scripts/check-devbox-prereqs.sh
bash ./scripts/collect-devbox-evidence.sh
```

See the documents under `docs/` for the full setup and validation workflow.

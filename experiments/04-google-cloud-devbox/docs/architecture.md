# DevBox Architecture

## Overview

Experiment 04 uses a Google Compute Engine VM as a remote development and validation host for future Compose-to-Aspire migration experiments.

The intended control flow is:

```text
Codex
  -> gcloud compute ssh
  -> Google Cloud DevBox
  -> Docker Compose validation
  -> Aspire validation
  -> Evidence collection
```

## Components

| Component | Responsibility |
| --- | --- |
| Local workstation | Runs `gcloud`, creates the VM, and opens SSH sessions. |
| Google Cloud project | Hosts the DevBox resources in `ai-agent-host-497515`. |
| Google Compute Engine VM | Provides a Linux host for Docker, Docker Compose, .NET SDK, and repository validation. |
| Repository clone | Contains experiments, smoke tests, Aspire projects, scripts, and reports. |
| Evidence scripts | Capture environment details, tool versions, Docker state, repository status, and validation logs. |

## Baseline topology

```text
Local workstation
  |
  | gcloud compute ssh
  v
Google Compute Engine VM
  |
  | git clone / pull
  v
compose-to-aspire-demo repository
  |
  | docker compose up / smoke tests
  v
Compose baseline validation
  |
  | dotnet build / dotnet run / smoke tests
  v
Aspire validation
  |
  | collect-devbox-evidence.sh
  v
reports/
```

## Security posture

- No credentials are stored in this repository.
- SSH access should use Google Cloud managed SSH behavior through `gcloud compute ssh`.
- VM access should be limited to authorized Google identities.
- Root login should not be used for routine work.
- Secrets required by future experiments should stay outside Git and be injected through explicit runtime configuration.

## Operational model

The DevBox is not a production service. It is a controlled development host that can be created, used for migration validation, stopped when idle, and deleted when no longer required.

The first implementation remains manual by design. Terraform may be introduced after the manual DevBox workflow is validated end to end.

# Google Cloud Setup Plan

## 1. Select the project

Use the existing Google Cloud project:

```bash
gcloud config set project ai-agent-host-497515
```

The local readiness check does not change the active project automatically. It reports the current project and prints guidance when it differs from the expected project.

## 2. Confirm billing

Confirm that billing is enabled for `ai-agent-host-497515` before creating a VM.

This repository does not include a billing automation script. Billing state should be checked in the Google Cloud Console or with an account that has the required billing permissions.

## 3. Enable required APIs

Required APIs:

- Compute Engine API: `compute.googleapis.com`
- Service Usage API: `serviceusage.googleapis.com`
- Cloud Resource Manager API: `cloudresourcemanager.googleapis.com`

The readiness script identifies missing APIs but does not enable them automatically.

If an API is missing, enable it explicitly:

```bash
gcloud services enable compute.googleapis.com --project ai-agent-host-497515
gcloud services enable serviceusage.googleapis.com --project ai-agent-host-497515
gcloud services enable cloudresourcemanager.googleapis.com --project ai-agent-host-497515
```

## 4. Create the VM

Review the defaults in `scripts/create-devbox-gce.sh`, then run:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/create-devbox-gce.sh
```

The script prints its configuration and requires confirmation before creating the VM.

## 5. Connect through SSH

Use:

```bash
bash ./scripts/connect-devbox.sh
```

This uses `gcloud compute ssh` with the configured project, zone, and VM name.

## 6. Install tooling

Install the required tools inside the VM:

- Git
- Docker Engine
- Docker Compose plugin
- .NET SDK
- curl
- jq
- bash
- unzip

Use current vendor installation guidance for Docker Engine and the .NET SDK. Avoid committing installation tokens, package credentials, or private keys.

## 7. Clone the repository

Clone this repository into the non-root user home directory on the DevBox.

Example:

```bash
git clone <repository-url> compose-to-aspire-demo
cd compose-to-aspire-demo
```

Use the appropriate repository URL for the account and access model. Do not store credentials in the repository.

## 8. Run validation checks

From the cloned repository:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/check-devbox-prereqs.sh
bash ./scripts/collect-devbox-evidence.sh
```

The prerequisite check should pass before future Compose or Aspire migration validations are attempted.

# SSH Access Model

## Principles

- Do not commit credentials.
- Do not commit private keys.
- Use `gcloud compute ssh` for Google Cloud managed SSH access.
- Prefer least privilege for Google identities and service accounts.
- Avoid root login for routine work.
- Keep secrets outside the repository.

## Local access flow

The expected access flow is:

```text
Local authenticated Google identity
  -> gcloud compute ssh
  -> Google Compute Engine VM
  -> non-root Linux user
```

`gcloud compute ssh` manages SSH key behavior through Google Cloud tooling. Any generated local SSH keys remain on the workstation and must not be copied into this repository.

## IAM expectations

The user creating and accessing the VM needs permissions to:

- view the project;
- view enabled services;
- create and describe Compute Engine instances;
- connect to the instance through SSH.

Use the narrowest practical roles for the operator. Avoid broad project ownership for routine validation work when a narrower role is sufficient.

## VM user model

Routine validation should run as a non-root user.

Use `sudo` only for system package installation and Docker setup. After Docker is installed, the validation user should have Docker access without using `sudo`.

## Secret handling

Future experiments may require application secrets, package feed credentials, or private repository credentials. Those values must be provided through explicit runtime configuration and must not be written into tracked files.

Acceptable locations include:

- local shell environment variables;
- Google Cloud Secret Manager;
- untracked local files protected by `.gitignore`;
- short-lived credentials managed outside the repository.

## Network exposure

Only SSH should be exposed by default. Application ports used during validation should bind locally on the VM unless remote browser access is explicitly required.

If public ingress is ever required for a validation step, document:

- the port;
- the reason;
- the source IP restriction;
- the cleanup step;
- the risk accepted for that run.

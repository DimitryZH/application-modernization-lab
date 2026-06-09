# SSH Access Model

## Principles

- Do not commit credentials.
- Do not commit private keys.
- Use `gcloud compute ssh --tunnel-through-iap` for Google Cloud managed SSH access.
- Prefer least privilege for Google identities and service accounts.
- Avoid root login for routine work.
- Keep secrets outside the repository.
- Block direct public SSH access even when the DevBox needs an external IP for outbound internet access.

## Local access flow

The expected access flow is:

```text
Local authenticated Google identity
  -> gcloud compute ssh --tunnel-through-iap
  -> Identity-Aware Proxy
  -> Google Compute Engine VM
  -> non-root Linux user
```

`gcloud compute ssh` manages SSH key behavior through Google Cloud tooling. Any generated local SSH keys remain on the workstation and must not be copied into this repository.

The DevBox uses the `devbox-iap-ssh` network tag. Two dedicated firewall rules enforce the access model:

- `devbox-allow-iap-ssh` allows TCP port 22 from the Google Cloud IAP TCP forwarding range `35.235.240.0/20` at priority `900`;
- `devbox-deny-public-ssh` denies TCP port 22 from `0.0.0.0/0` at priority `1000`.

The higher-priority IAP allow rule permits the approved tunnel path before the public SSH deny rule is evaluated.

The default connection helper enables IAP tunneling:

```bash
bash ./scripts/connect-devbox.sh
```

## IAM expectations

The user creating and accessing the VM needs permissions to:

- view the project;
- view enabled services;
- create and describe Compute Engine instances;
- connect to the instance through SSH;
- establish an IAP TCP tunnel.

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

The DevBox retains an ephemeral external IP because the current default-network design has no Cloud NAT and the validation workflow requires outbound internet access. Direct public SSH is blocked by the tagged deny rule, while approved SSH reaches the VM through IAP.

Application ports used during validation should bind locally on the VM unless remote browser access is explicitly required.

If public ingress is ever required for a validation step, document:

- the port;
- the reason;
- the source IP restriction;
- the cleanup step;
- the risk accepted for that run.

Do not modify shared default-network firewall rules as part of routine DevBox work because they may affect unrelated resources. If the DevBox pattern becomes a reusable platform standard, move it to a dedicated network in a separate infrastructure change.

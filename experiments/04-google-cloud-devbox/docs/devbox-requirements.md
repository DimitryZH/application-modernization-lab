# DevBox Requirements

## Baseline Google Cloud settings

| Setting | Recommended value |
| --- | --- |
| Project | `ai-agent-host-497515` |
| Region | `us-central1` |
| Zone | `us-central1-a` |
| VM name | `compose-aspire-devbox-01` |
| Machine type | `e2-standard-2` |
| Boot disk | 80 GB `pd-balanced` |
| Operating system | Ubuntu LTS |

The default VM size prioritizes low cost while still providing enough CPU and memory for small Docker Compose and Aspire workloads. Larger migrations may require a larger machine type or boot disk.

## Required tools inside the VM

- Git
- Docker Engine
- Docker Compose plugin
- .NET SDK
- curl
- jq
- bash
- unzip

Optional:

- Chrome or Chromium for future UI smoke tests that require a browser engine.

## Minimum runtime expectations

| Resource | Minimum | Recommended |
| --- | --- | --- |
| CPU | 2 vCPU | 2-4 vCPU |
| Memory | 4 GB | 8 GB or more |
| Free disk | 20 GB | 50 GB or more |

Docker images, NuGet packages, build outputs, and evidence artifacts can grow quickly. Disk usage should be checked before and after validation runs.

## Network expectations

The DevBox needs outbound internet access for:

- package installation;
- Docker image pulls;
- NuGet package restore;
- Git repository access.

The current minimal design retains an ephemeral external IP for outbound internet access because the default network has no Cloud NAT. SSH access should use IAP TCP forwarding and OS Login.

The `devbox-iap-ssh` network tag must have a higher-priority rule that allows TCP port 22 only from `35.235.240.0/20` and a lower-priority rule that denies TCP port 22 from `0.0.0.0/0`.

Do not expose application ports publicly unless a specific validation requires it and the risk is understood.

## Repository expectations

The repository should be cloned under the normal non-root user account. Validation commands should run as that user, not as root.

Docker access should work without `sudo` for repeatable automation. If the user is added to the `docker` group, the SSH session must be restarted before validating Docker access.

## Cost-aware defaults

The recommended defaults are development-oriented and should not be treated as production sizing. Stop the VM when it is not actively used, and delete it when the experiment is complete.

# Stage C DevBox Validation Report

## Summary

Stage C transformed the provisioned Google Cloud DevBox into a validated Docker Compose and .NET migration execution environment.

Final status: `PASS`

## Date and environment

- Validation time: 2026-06-08T17:20:43Z
- VM name: `compose-aspire-devbox-01`
- OS: Ubuntu 24.04.4 LTS
- Kernel: Ubuntu GCP kernel `6.17.0-1016-gcp`
- CPU: 2 vCPU
- Memory: approximately 7.8 GiB
- Root filesystem: approximately 77 GiB
- Free disk after installation: approximately 73 GiB
- Repository validation commit: `57ddf34488c236b66e47b715308e5df503f6d9df`

Environment-specific IP addresses, SSH fingerprints, and OS Login identity values are intentionally omitted from this Git-tracked report.

## Initial state

Installed before Stage C:

- Git
- curl
- jq
- bash

Missing before Stage C:

- Docker Engine
- Docker Compose plugin
- .NET SDK
- unzip

## Installation sources

| Tool | Source |
| --- | --- |
| Docker Engine | Official Docker Ubuntu repository |
| Docker Compose plugin | Official Docker Ubuntu repository |
| .NET 10 SDK | Official Ubuntu 24.04 updates/security repository |
| unzip | Official Ubuntu repository |

The official Microsoft Ubuntu repository was evaluated for .NET packages. It did not provide `dotnet-sdk-9.0`, and the required `dotnet-sdk-10.0` package was available from the official Ubuntu repository. The unused Microsoft repository configuration was removed after installation.

## Installation command summary

The following command shapes were used through `gcloud compute ssh`:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg unzip git

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  dotnet-sdk-10.0

sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker
```

The SSH session was re-established after adding the validation user to the `docker` group.

## Installed tool versions

| Tool | Validated version |
| --- | --- |
| Git | `2.43.0` |
| Docker Engine | `29.5.3` |
| Docker Compose plugin | `v5.1.4` |
| containerd | `2.2.4` |
| .NET SDK | `10.0.108` |
| .NET runtime | `10.0.8` |
| curl | `8.5.0` |
| jq | `1.7` |
| unzip | `6.00` |
| bash | `5.2.21` |

## Docker validation

Commands:

```bash
docker version
docker compose version
docker info
docker run --rm hello-world
```

Results:

- Docker daemon is active and enabled.
- Docker is accessible by the non-root validation user without `sudo`.
- Docker uses the `overlayfs` storage driver and cgroup v2.
- Docker Compose plugin is available.
- The official `hello-world` container pulled and ran successfully.

Docker validation result: `PASS`

## .NET validation

Commands:

```bash
dotnet --info
dotnet --list-sdks
```

Results:

- .NET SDK `10.0.108` is installed.
- .NET runtime `10.0.8` is installed.
- No .NET workloads are installed, which is acceptable for Stage C.
- `dotnet-sdk-9.0` was not available from the evaluated Ubuntu or Microsoft apt repositories.

.NET validation result: `PASS`

The missing .NET 9 SDK is a documented compatibility warning for repository projects that still target `net9.0`. It does not block Stage C because the DevBox has a supported .NET SDK and no Aspire build was required in this stage.

## Prerequisite validation

Command:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/check-devbox-prereqs.sh
```

Result:

```text
PASS=14 WARN=1 FAIL=0
```

The only warning was that optional Chrome or Chromium is not installed.

Prerequisite validation result: `PASS`

## Evidence collection

Command:

```bash
bash ./scripts/collect-devbox-evidence.sh
```

Result:

- A timestamped raw evidence file was created on the DevBox.
- The evidence file contained 216 lines.
- A problem scan found no failures, errors, permission issues, or missing required tools.
- Raw evidence remains on the DevBox and is excluded from Git by `reports/.gitignore` because it contains environment-specific data.

Evidence collection result: `PASS`

## Issues encountered and fixes applied

| Issue | Resolution |
| --- | --- |
| Docker Engine, Compose plugin, .NET SDK, and unzip were missing. | Installed required packages from official repositories. |
| Docker access initially required group configuration. | Added the validation user to the `docker` group and re-established the SSH session. |
| Combined installation attempt included unavailable `dotnet-sdk-9.0`. | Installed supported `dotnet-sdk-10.0` and documented the .NET 9 compatibility warning. |
| Microsoft apt repository was not required for the available .NET package. | Removed the unused repository configuration after confirming .NET 10 came from Ubuntu repositories. |
| Optional Chrome or Chromium is not installed. | Documented as a non-blocking warning. |

## Final Stage C status

`PASS`

The DevBox is ready for Stage D remote Docker Compose baseline validation.

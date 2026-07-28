# Experiment 07B: Bank of Anthos Docker Compose to .NET Aspire

This experiment represents the validated Experiment 07A Bank of Anthos Docker Compose baseline as a .NET Aspire AppHost.

The Compose input is frozen at commit `3de8845412853525aeb77d85db23f2d14b1bfc73` under `../01-kubernetes-to-compose/`. Application source and the Compose baseline are not modified.

## Scope

- Runtime model: image-only Aspire container resources.
- Application source changes: none.
- ServiceDefaults: not used for the prebuilt Bank of Anthos containers.
- Default host exposure: only `frontend` on `http://127.0.0.1:8080`.
- Stateful dependencies: `accounts-db` and `ledger-db` remain separate PostgreSQL containers with independent named Docker volumes.
- Local JWT material: generated under `.local/jwt/` and mounted read-only with private key access limited to `userservice`.
- Optional service: `loadgenerator`, disabled unless explicitly enabled.

## Structure

```text
02-compose-to-aspire/
|-- BankOfAnthos.Aspire.sln
|-- README.md
|-- scripts/
|   |-- generate-jwt-keys.sh
|   `-- validate-aspire.ps1
`-- src/
    `-- BankOfAnthos.AppHost/
        |-- AppHost.cs
        `-- BankOfAnthos.AppHost.csproj
```

## Prerequisites

- .NET SDK 10 or later.
- Docker-compatible container runtime available to Aspire.
- PowerShell 7 or later for the validation script.
- `openssl` for local JWT key generation.

## Start

From this directory:

```bash
./scripts/generate-jwt-keys.sh
dotnet run --project ./src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj
```

Open the frontend:

```text
http://127.0.0.1:8080
```

If port `8080` is occupied, stop the conflicting process or run with an alternate port and pass that URL to validation:

```bash
dotnet run --project ./src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -- --BankOfAnthos:FrontendPort=18080
```

## Validate

Validate an already running AppHost:

```bash
/home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File ./scripts/validate-aspire.ps1
```

Start the AppHost from the validator, run the checks, and stop the AppHost process afterward:

```bash
/home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File ./scripts/validate-aspire.ps1 -StartAppHost
```

Useful parameters:

- `-BaseUrl`, default `http://127.0.0.1:8080`.
- `-StartupTimeoutSeconds`, default `300`.
- `-StableSeconds`, default `30`.
- `-IdentityOnly`, limits validation to readiness plus Aspire container identity.
- `-SkipCleanup`, leaves a validator-started AppHost process running.

The validator exits non-zero when required services are missing, stopped, unstable, not Aspire-managed, not part of one shared DCP creator identity, missing required environment, lacking expected persistence mounts, unreachable through the frontend, backend `/ready` checks fail from inside the frontend container, deterministic transaction evidence is absent, or when local generated state is tracked.

## Optional Load Generator

The load generator is disabled by default, matching the Compose profile behavior.

Enable it for a separate smoke run:

```bash
dotnet run --project ./src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -- --BankOfAnthos:EnableLoadGenerator=true
```

Optional overrides:

```bash
dotnet run --project ./src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -- --BankOfAnthos:EnableLoadGenerator=true --BankOfAnthos:LoadGenerator:Users=5 --BankOfAnthos:LoadGenerator:LogLevel=error
```

The load generator points to `frontend:8080` inside the Aspire network and is not part of the required deterministic validation path.

## Equivalence Assessment

### Represented Services

| Compose service | Aspire resource | Notes |
| --- | --- | --- |
| `frontend` | container | only published endpoint, loopback `8080` by default |
| `userservice` | container | mounts private and public JWT keys read-only |
| `contacts` | container | mounts public JWT key read-only |
| `ledgerwriter` | container | preserves Java, ledger DB, and service API environment |
| `balancereader` | container | preserves Java ledger cache environment |
| `transactionhistory` | container | preserves Java history cache environment |
| `accounts-db` | container | independent persistent volume |
| `ledger-db` | container | independent persistent volume |
| `loadgenerator` | optional container | disabled by default |

### Configuration

The AppHost preserves Compose service names in environment values such as `userservice:8080`, `accounts-db:5432`, and `ledger-db:5432` because the pinned images expect those DNS names directly. It keeps tracing and metrics disabled for local parity with the validated Compose baseline. The Java ledger services also preserve the Compose `HOSTNAME` values (`balancereader-local-1`, `transactionhistory-local-1`, and `ledgerwriter-local-1`) because the pinned images parse Kubernetes-style hostnames during startup.

### Secrets

The local RSA private key is mounted only into `userservice` at `/tmp/.ssh/privatekey`. The public key is mounted into the services that validate JWTs at `/tmp/.ssh/publickey`. Generated keys, cookies, logs, dumps, runtime output, and validation state are ignored by git.

### Persistence

`accounts-db` and `ledger-db` are separate containers and separate named Docker volumes:

- `bank-of-anthos-aspire-accounts-db-data`
- `bank-of-anthos-aspire-ledger-db-data`

Normal AppHost shutdown stops the containers but preserves volumes. A full reset removes the volumes explicitly.

### Isolation And Negative Validation

The validator selects resources by Aspire/DCP labels, resource name pattern, expected image, and one shared DCP creator identity. Docker Compose containers using the same pinned images cannot satisfy validation because they do not carry the Aspire/DCP labels or shared AppHost creator identity.

Recommended negative checks:

- With only the Compose baseline running, `validate-aspire.ps1 -BaseUrl <compose-url>` must fail at Aspire container identity.
- With `ledger-db` stopped or missing from the Aspire run, validation must fail.
- With port `8080` occupied, AppHost startup should fail or an alternate `BankOfAnthos:FrontendPort` should be used and documented.

## Cleanup And Reset

Stop the AppHost with `Ctrl+C`. Aspire stops the managed resources it started.

If a run is interrupted, inspect containers by Aspire/DCP labels before removal:

```bash
docker ps --filter label=com.microsoft.developer.usvc-dev.group-version=usvc-dev.developer.microsoft.com/v1
```

Full reset of persisted Aspire database state:

```bash
docker volume rm bank-of-anthos-aspire-accounts-db-data bank-of-anthos-aspire-ledger-db-data
rm -rf .local
```

Compose cleanup remains separate and should only be used for Experiment 07A runs.

# Online Boutique .NET Aspire Migration

This experiment represents the validated Google Cloud Online Boutique Docker Compose baseline as a .NET Aspire AppHost.

The Compose baseline remains unchanged under `../01-kubernetes-to-compose/` and is the equivalence reference for this migration.

## Scope

- Upstream application: Google Cloud Online Boutique `v0.10.6`.
- Runtime model: image-based Aspire container resources.
- Application source changes: none.
- ServiceDefaults: not used, because this repository does not include local Online Boutique service source projects.
- Default host exposure: only `frontend` on `http://localhost:8080`.
- Optional service: `loadgenerator`, disabled unless explicitly enabled.

## Structure

```text
02-compose-to-aspire/
|-- OnlineBoutique.Aspire.sln
|-- README.md
|-- scripts/
|   `-- validate-aspire.ps1
`-- src/
    `-- OnlineBoutique.AppHost/
        |-- AppHost.cs
        `-- OnlineBoutique.AppHost.csproj
```

## Prerequisites

- .NET SDK 10 or later.
- .NET Aspire AppHost SDK package restore access.
- Docker-compatible container runtime available to Aspire.
- PowerShell 7 or later for the validation script.

## Start

From this directory:

```powershell
dotnet run --project .\src\OnlineBoutique.AppHost\OnlineBoutique.AppHost.csproj
```

Open the frontend:

```text
http://localhost:8080
```

The Aspire dashboard URL is printed by the AppHost at startup. It shows the required resources, endpoints, logs, and container lifecycle state.

If port `8080` is already in use, stop the conflicting process or use the frontend endpoint shown by the Aspire dashboard and pass it to validation with `-BaseUrl`.

## Validate

Validate an already running AppHost:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\validate-aspire.ps1
```

Start the AppHost from the validator, run the checks, and stop the AppHost process afterward:

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\validate-aspire.ps1 -StartAppHost
```

Useful parameters:

- `-BaseUrl`, default `http://localhost:8080`.
- `-StartupTimeoutSeconds`, default `180`.
- `-StableSeconds`, default `30`.
- `-SkipCleanup`, leaves a validator-started AppHost process running.

The validator:

1. builds the AppHost;
2. optionally starts the AppHost;
3. waits for `GET /_healthz` to return `ok`;
4. exercises product browsing, product detail, add-to-cart, Redis-backed cart display, checkout, and order completion with one web session;
5. checks required Aspire-managed service containers are running, not restarting, and exited with code `0`;
6. verifies those containers have Aspire/DCP resource labels matching the expected AppHost resources;
7. checks key environment variables match the Compose baseline;
8. prints the resolved image inventory and Aspire/DCP resource labels.

## Optional Load Generator

The load generator is disabled by default, matching the Compose profile behavior.

Enable it for a separate smoke run:

```powershell
dotnet run --project .\src\OnlineBoutique.AppHost\OnlineBoutique.AppHost.csproj -- --OnlineBoutique:EnableLoadGenerator=true
```

Optional overrides:

```powershell
dotnet run --project .\src\OnlineBoutique.AppHost\OnlineBoutique.AppHost.csproj -- --OnlineBoutique:EnableLoadGenerator=true --OnlineBoutique:LoadGenerator:Users=10 --OnlineBoutique:LoadGenerator:Rate=1
```

The load generator points to `frontend:8080` inside the Aspire network and is not part of the required validation path.

## Cleanup

Stop the AppHost with `Ctrl+C`. Aspire stops the managed resources it started.

If a run is interrupted, use Docker to inspect and remove leftover Online Boutique containers by image or by the Aspire dashboard resource names. The Compose baseline cleanup command remains separate:

```powershell
cd ..\01-kubernetes-to-compose
docker-compose -p online-boutique-exp06 down -v --remove-orphans
```

Do not use Compose cleanup commands for Aspire unless you intentionally started the Compose baseline.

## Troubleshooting

Check the AppHost build:

```powershell
dotnet build .\OnlineBoutique.Aspire.sln
```

Check frontend health:

```powershell
Invoke-WebRequest http://localhost:8080/_healthz -UseBasicParsing
```

Common issues:

- Port `8080` is already occupied. Free the port or validate with the frontend endpoint shown in the dashboard.
- Images cannot be pulled. Verify Docker registry access to `us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo` and Docker Hub for Redis.
- The dashboard shows running containers before the app is ready. Wait for frontend `/_healthz`; container running state is not treated as readiness.
- The dashboard shows logs and resource state for these prebuilt polyglot images, but rich Aspire-configured traces are not expected because service source code was not modified.

## Equivalence Assessment

### Represented Services

The AppHost represents all required Compose services:

| Service | Aspire resource | Image handling |
|---|---|---|
| `frontend` | container | digest-pinned Online Boutique `v0.10.6` image |
| `productcatalogservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `currencyservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `cartservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `redis-cart` | container | digest-pinned `redis:alpine` image |
| `checkoutservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `shippingservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `paymentservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `emailservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `recommendationservice` | container | digest-pinned Online Boutique `v0.10.6` image |
| `adservice` | container | digest-pinned Online Boutique `v0.10.6` image |

`loadgenerator` is represented as an optional container resource and is disabled by default.

### Dependencies

The AppHost mirrors the Compose startup relationships:

- `cartservice` waits for `redis-cart`.
- `recommendationservice` waits for `productcatalogservice`.
- `checkoutservice` waits for `cartservice`, `currencyservice`, `emailservice`, `paymentservice`, `productcatalogservice`, and `shippingservice`.
- `frontend` waits for `adservice`, `cartservice`, `checkoutservice`, `currencyservice`, `productcatalogservice`, `recommendationservice`, and `shippingservice`.
- Optional `loadgenerator` waits for `frontend`.

### Configuration Mapping

The service environment values preserve the Compose baseline, including:

- `REDIS_ADDR=redis-cart:6379` for `cartservice`.
- `EMAIL_SERVICE_ADDR=emailservice:8080` for `checkoutservice`.
- `SHOPPING_ASSISTANT_SERVICE_ADDR=shoppingassistantservice:80` for `frontend`, without adding an out-of-scope shopping assistant service.
- profiler flags matching the Compose baseline.

The images expect direct `host:port` environment variables, so the AppHost preserves the baseline service DNS names and container ports instead of replacing them with Aspire connection strings.

### Endpoints

Only `frontend` is host-published by default on `http://localhost:8080`. Backend gRPC endpoints and Redis stay internal to the Aspire-managed network.

### Stateful Dependencies

`redis-cart` uses the same image and command intent as Compose:

```text
redis-server --save "" --appendonly no
```

No persistent named volume is attached. This preserves ephemeral cart state for local runs. The Compose baseline used `tmpfs: /data`; the AppHost preserves disabled persistence and no persistent volume, but does not rely on a Compose-specific `tmpfs` declaration.

### Health And Readiness

Aspire provides dashboard resource state and logs. Functional readiness is still validated through:

- `GET /_healthz` on the frontend;
- product listing and product detail requests;
- Redis-backed cart mutation and display;
- checkout and order completion;
- required container stability after the workflow.

This intentionally keeps backend health behavior equivalent to the Compose baseline rather than adding source-level probes to prebuilt images.

### Functional Workflow

The Aspire validator mirrors the Compose validator:

1. home page contains `Sunglasses`;
2. product page for `OLJCESPC7Z` renders `Add To Cart`;
3. posting `product_id=OLJCESPC7Z` and `quantity=1` to `/cart` returns a cart containing `Sunglasses`;
4. posting the test checkout payload to `/cart/checkout` returns a page containing `Your order is complete`;
5. required containers remain running and non-restarting during the stability window.

### Intentional Differences

- Aspire AppHost replaces Compose as the local orchestrator, so the dashboard and lifecycle commands differ.
- Redis does not declare Compose `tmpfs`; it remains ephemeral through disabled persistence and no persistent volume.
- The optional load generator is controlled by AppHost configuration instead of a Compose profile.
- The dashboard does not imply full distributed tracing for image-only services because no service source code or telemetry wiring was changed.
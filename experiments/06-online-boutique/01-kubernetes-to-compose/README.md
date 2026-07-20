# Online Boutique Docker Compose Baseline

This directory contains a Docker Compose baseline for Google Cloud Online Boutique.

The baseline is derived from the official Kubernetes manifests and Skaffold configuration for the selected upstream release. It does not modify application source code and does not include any .NET Aspire implementation.

## Upstream Selection

- Repository: `GoogleCloudPlatform/microservices-demo`
- Tag: `v0.10.6`
- Commit: `5b3a712ab85ccb8f6f7cd5b720d36ba9a8d041eb`

The copied upstream reference files are under `upstream/` and retain the upstream Apache 2.0 license.

## Services

The required Compose stack runs:

- `frontend` on `http://localhost:8080`
- `adservice`
- `cartservice`
- `checkoutservice`
- `currencyservice`
- `emailservice`
- `paymentservice`
- `productcatalogservice`
- `recommendationservice`
- `shippingservice`
- `redis-cart`

The optional `loadgenerator` service is available through the `loadgenerator` Compose profile.

Only `frontend` is published to the host. Internal application services and Redis stay on the Compose network.

## Start

```powershell
cd experiments/06-online-boutique/01-kubernetes-to-compose
docker-compose -p online-boutique-exp06 up -d
```

Open `http://localhost:8080`.

## Validate

```powershell
cd experiments/06-online-boutique/01-kubernetes-to-compose
powershell -ExecutionPolicy Bypass -File .\scripts\validate-compose.ps1
```

The validator checks Compose configuration, pulls the pinned images, starts the stack, waits for the frontend, exercises a browse/cart/checkout path, confirms required containers stay running, and shuts the stack down. See `validation-results.md` for the latest local result.

## Optional Load Generator

```powershell
docker-compose -p online-boutique-exp06 --profile loadgenerator up -d loadgenerator
```

The load generator is not required for the main validation path.

## Troubleshooting

Check the stack state:

```powershell
docker-compose -p online-boutique-exp06 ps
```

Check recent logs for a service:

```powershell
docker-compose -p online-boutique-exp06 logs --tail 100 frontend
```

Reset the environment:

```powershell
docker-compose -p online-boutique-exp06 down -v --remove-orphans
```

## Cleanup

```powershell
docker-compose -p online-boutique-exp06 down -v --remove-orphans
```

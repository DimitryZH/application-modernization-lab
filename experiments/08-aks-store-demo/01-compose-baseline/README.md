# Experiment 08A: AKS Store Demo Docker Compose Baseline

This directory contains a tracked snapshot of the official AKS Store Demo source pinned to commit `7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5` and a local Compose baseline approved for Experiment 08A validation.

## Run

```bash
./scripts/start-compose.sh
```

Default UI endpoints are loopback only:

- Storefront: `http://127.0.0.1:8080`
- Admin: `http://127.0.0.1:8081`

## Validate

```bash
./scripts/validate-compose.sh
./scripts/validate-negative.sh
```

The positive validator builds and starts the nine required non-AI services, verifies Compose identity labels, checks loopback exposure, validates product and unique current-run order workflows, verifies RabbitMQ queue identity, verifies DocumentDB-backed order visibility through makeline/admin APIs, classifies persistence, cleans up, and performs a fresh repeat run.

The negative validator stops only the Experiment 08 RabbitMQ container and verifies the native identity validation fails non-zero before restoring RabbitMQ.

## Cleanup

```bash
./scripts/cleanup-compose.sh
```

Full reset, including any Compose-managed container state:

```bash
./scripts/cleanup-compose.sh --volumes
rm -rf .local
```

## Optional AI

The default PASS criteria exclude `ai-service`. To experiment manually with the optional AI profile, provide local untracked credentials and run:

```bash
docker compose --profile ai -p aks-store-demo-compose up -d
```

No real API key or model credential may be committed.

# Experiment 08B: AKS Store Demo Compose to Aspire

This experiment migrates the accepted Experiment 08A Docker Compose baseline to a .NET Aspire AppHost while keeping the accepted application source immutable.

## Version Pins

- .NET SDK: `10.0.110`, pinned in `global.json`.
- Aspire AppHost SDK: `Aspire.AppHost.Sdk/13.4.6`, pinned in `src/AppHost/AksStore.AppHost.csproj`.
- Aspire hosting package source: `Aspire.Hosting.AppHost` and `Aspire.AppHost.Sdk` `13.4.6`, stable NuGet release with `net10.0` support.

No Aspire workload is required for this AppHost. The AppHost uses the SDK package and Docker/DCP orchestration supplied by Aspire.

## Scope

The AppHost lives under `src/AppHost` and represents the nine required non-AI services:

1. `documentdb`
2. `rabbitmq`
3. `order-service`
4. `makeline-service`
5. `product-service`
6. `store-front`
7. `store-admin`
8. `virtual-customer`
9. `virtual-worker`

The optional `ai-service` is absent from the default topology and is only added when `AksStore:EnableAiService=true` is supplied to the AppHost configuration. Default validation does not require AI credentials or external AI services.

## Runtime Model

`documentdb` and `rabbitmq` use the accepted pinned images from Experiment 08A. Application containers are built from Dockerfiles in the immutable `../01-compose-baseline/src/<service>` directories through read-only relative AppHost references.

Only these endpoints are host-published:

- `store-front`: `http://127.0.0.1:8080`
- `store-admin`: `http://127.0.0.1:8081`

Backend services, RabbitMQ, and DocumentDB remain internal to the Aspire container network. The application-visible internal names remain the accepted service names such as `rabbitmq`, `documentdb`, `order-service`, and `makeline-service`.

## Commands

Run from this directory:

```bash
dotnet build src/AppHost/AksStore.AppHost.csproj
scripts/validate-aspire.sh --start-apphost
scripts/validate-negative.sh
bash scripts/validate-cleanup-isolation.sh
bash scripts/validate-failure-cleanup.sh
scripts/cleanup-aspire.sh --full-reset
```

Validation evidence is written to `.local/validation/`, which is ignored and must not be committed.

## Validation Contract

The positive validator verifies the pinned versions, the Experiment 08A source hash, AppHost build, current Aspire/DCP resource identity, loopback-only UI exposure, backend internal exposure, required environment values, product proxy workflow, unique current-run order submission, RabbitMQ `orders` queue, makeline consumption, DocumentDB-backed order visibility, makeline restart persistence, cleanup, and untracked local evidence.

The validator captures the current AppHost PID, AppHost process start ticks, and persisted DCP creator identity in `.local/run/apphost-identity.env`. Aspire/DCP labels use the DCP apiserver creator process, while the AppHost process monitors that DCP runtime. Positive validation and cleanup verify the stored AppHost PID is still the same running process, that the DCP creator process id/start-time labels match the persisted identity, and that all nine required Experiment 08B resources belong to that exact identity before selecting containers. Docker Compose containers with the same images or service names, stale Aspire containers, and unrelated DCP-labeled containers cannot satisfy validation or be removed by cleanup.

The negative validator always starts a fresh Experiment 08B AppHost instance, stops only that current-run Aspire `rabbitmq` resource, requires the native validation path to fail non-zero on the RabbitMQ/order workflow, restores RabbitMQ, restarts dependent services, submits a fresh unique order, verifies makeline/DocumentDB recovery, and cleans up only Experiment 08B resources.

Cleanup fails safely when the persisted AppHost identity is absent, incomplete, stale, ambiguous, inconsistent with the stored AppHost process, or missing any required Experiment 08B resource. Failure traps restore paused workload containers and RabbitMQ when required, preserve diagnostic evidence under `.local/validation/`, stop the owned AppHost, and remove only containers matching the persisted Experiment 08B AppHost identity.

## Persistence

No named volume is added. DocumentDB state remains container-local. The validator proves makeline restart persistence while the DocumentDB container remains unchanged, and does not claim durability across DocumentDB recreation or full reset.

## Rollback

Repository rollback is removal of `experiments/08-aks-store-demo/02-compose-to-aspire/` before merge. Runtime rollback is `scripts/cleanup-aspire.sh --full-reset`, followed by manual removal only of containers that carry the Experiment 08B Aspire/DCP resource labels if cleanup is interrupted.

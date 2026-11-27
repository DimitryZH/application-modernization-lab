# Trail Supply — workload foundation

Trail Supply is a separate workload under development, derived from Online Shop
at `67b6cd85ae01c698bbf86904d953d5145b7b5820`. The original workload remains
unchanged. This stage preserves the existing storefront, catalog, advertising,
backend behavior and assets; visual modernization is deferred.

All application/protocol sources and Dockerfiles are inherited byte-for-byte.
Operational service names, protobuf packages, the `online-shop` telemetry
namespace and `ONLINE_SHOP_*` runtime settings intentionally remain unchanged.
The accepted recommendation catalog deadline correction is included.

## Build and run boundaries

- [Build contract and planner](docs/BUILDING.md): eleven independent source builds
  rooted entirely in this workload; Redis remains an external dependency.
- [Local browser review](local/README.md): source-built images, unique Compose
  project, localhost storefront, explicit startup/status/cleanup; stays running
  until the owner stops it. Docker Desktop is not started by any helper.
- [Runtime requirements](docs/RUNTIME.md), [telemetry semantics](docs/TELEMETRY.md),
  and [Redis contract](docs/REDIS.md) retain the inherited service interfaces.
- [Validation](docs/VALIDATION.md) distinguishes static checks from future builds,
  browser review and runtime acceptance.

`local/compose.yaml` is for manual review. `validation/otel/compose.yaml` remains
an isolated fault/telemetry test harness with automated cleanup. Neither is a
production deployment. The inherited `kubernetes/online-shop.yaml` and
`images.lock.json` retain historical artifact references, not independently built
Trail Supply artifacts. Do not deploy that manifest as a Trail Supply release.

## Lineage and acceptance status

[Source lineage](source-lineage.json) records the accepted AML base, upstream
snapshot and omitted historical evidence paths. [Upstream record](docs/UPSTREAM.md)
links to the immutable original evidence; no result files were copied as new
acceptance. [Foundation results](validation/FOUNDATION-RESULTS.md) records only
checks actually executed for this stage.

Container builds, Docker/Compose runtime acceptance, browser review, image
publication and deployment have not been performed for Trail Supply. The Redis
canonical mirror's inherited publication/equality/attestation prerequisites remain
pending; a pinned reference alone does not prove that it is pullable.

Future SDP consumers must select `workloads/trail-supply`, its planner from the
same immutable revision, and its own build/release evidence. Keep the existing
service identities and namespace; distinguish parallel environments through
platform isolation and resource attributes. No downstream repository is changed.

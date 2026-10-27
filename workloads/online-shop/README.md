# Online Shop

Canonical sources for Online Shop: ten polyglot application services, a load generator, manual OpenTelemetry instrumentation and portable Kubernetes configuration. Redis is an external ephemeral-cache dependency.

See the [Application Modernization Lab overview](../../README.md) for the architecture, image/build boundaries and platform responsibilities.

## Documentation

- [Build inputs and consumer interface](docs/BUILDING.md)
- [Runtime requirements and Kubernetes profile](docs/RUNTIME.md)
- [Manual OpenTelemetry](docs/TELEMETRY.md)
- [Redis runtime contract](docs/REDIS.md)
- [Upstream, licensing and historical image origins](docs/UPSTREAM.md)
- [Static validation record](docs/VALIDATION.md)

Source trees, Dockerfiles, `protos/`, `kubernetes/`, `LICENSE`, JSON contracts and `build_plan.py` remain at their existing workload paths. Bare `BUILDING.md` references in `build.contract.json` now refer to `docs/BUILDING.md`; the contract and executable interface are unchanged.

## Validation

- [Clean-source build acceptance](validation/build/RESULTS.md)
- [Telemetry reproduction instructions](validation/otel/README.md)
- [Telemetry acceptance results](validation/otel/RESULTS.md)
- [Redis acceptance results](validation/otel/REDIS-RESULTS.md)

Validation tools and evidence remain in `validation/`. Historical result files retain their original links: old `../../REDIS.md` references resolve conceptually to [docs/REDIS.md](docs/REDIS.md). Recorded source builds do not relabel historical published images or establish downstream deployment.

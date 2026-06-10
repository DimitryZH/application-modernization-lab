# Failure Scenarios and Migration Risks

## Built-In Failure Scenarios

The feature-flag configuration includes intentional failure controls. Examples include:

- product catalog failures;
- recommendation cache failures;
- Kafka queue problems;
- payment failures.

The inspected default variants were `off`. These controls are valuable for later equivalence testing because they exercise degraded behavior and telemetry generation.

## Observed Baseline Limitations

### OpenSearch Readiness Timing

The official `make start` target failed twice because OpenSearch was still unhealthy when Compose evaluated its dependent services. OpenSearch later became healthy without an OOM or source change.

Continuing the same four-layer Compose deployment without another forced recreation started all dependent services. This is a startup-readiness limitation in the upstream baseline and DevBox environment, not a migration failure.

### Fraud Detection Restart Loop

`fraud-detection` repeatedly restarted because its flagd client interpreted the configured target as an unsupported Unix resolver address. The container had restarted three times during validation.

This is an upstream image or runtime configuration limitation. A future Aspire deployment must not be classified as equivalent merely because the same unstable behavior is reproduced; the difference must be documented explicitly.

### Load Generator HTTP Failures

The Load Generator remained running but reported approximately 4 percent failed requests, primarily HTTP 500 responses from storefront data requests. This establishes that endpoint availability and workload correctness are separate baseline criteria.

### Partial Startup Telemetry Errors

Kafka could not export telemetry before the Collector started. Accounting initially subscribed before the `orders` topic existed. Both recovered sufficiently for Kafka to become healthy and for accounting to consume order events.

## Migration Risks

- Multi-layer Compose merge semantics may be lost if only the base file is translated.
- Force-recreate behavior can repeatedly reset slow dependencies.
- Services without health checks can appear running while crash-looping or functionally degraded.
- Dynamic host ports are implementation details and should not become migration contracts.
- Docker socket and host filesystem mounts require explicit security review.
- No named volume exists; persistence expectations must be confirmed rather than inferred.
- High aggregate memory limits and no DevBox swap increase startup and validation sensitivity.
- Intentional failure flags can be confused with migration defects unless their state is recorded.

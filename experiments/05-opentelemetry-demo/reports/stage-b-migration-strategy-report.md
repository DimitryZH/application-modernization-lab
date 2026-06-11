# Stage B: Full Aspire Migration Strategy Report

## Result

**PASS**

Stage B produced a complete engineering strategy for migrating the resolved
29-service OpenTelemetry Demo deployment to .NET Aspire. The strategy is for a
full-application migration, not a subset migration.

## Scope and Method

Stage B reviewed all required Stage A documentation and verified key details
directly against the pinned upstream source clone at commit
`b5320139de38b789654a9653d5c4fda441b5cb8f`.

The four Compose layers were resolved together to verify:

- all 29 services;
- images and Dockerfile build contexts;
- ports and stable host-port contracts;
- merged dependency conditions;
- environment-variable names without copying secret values;
- commands, configuration mounts, health checks, memory limits, and ulimits;
- Kafka and Collector configuration layering.

No Aspire implementation was created. No upstream source or Compose file was
modified. No new full runtime validation was run, and the Stage A running stack
was not stopped.

## Documents Created

- `docs/migration-strategy.md`
- `docs/aspire-resource-mapping.md`
- `docs/stage-c-implementation-plan.md`
- `reports/stage-b-migration-strategy-report.md`

The Experiment 05 roadmap was updated to record Stage B completion.

## Services Analyzed

| Category | Count |
| --- | ---: |
| Application services | 16 |
| Platform and support services | 8 |
| Observability services | 5 |
| Total resolved services | **29** |
| Total mapped services | **29** |
| Silently omitted services | **0** |

## Migration Approach

The recommended first migration preserves behavior using pinned prebuilt
upstream images and explicit Aspire topology:

- Aspire native PostgreSQL and Redis-compatible resources are candidates for
  `astronomy-db` and `valkey-cart`, but only if exact runtime behavior can be
  retained; explicit containers are the accepted fallback.
- Kafka remains the exact instrumented demo KRaft image as an Aspire container
  resource.
- Application and support services use Aspire container resources with pinned
  prebuilt images. Dockerfile resources are a fallback or optional rebuild
  mode.
- The Collector and the complete Jaeger, Prometheus, OpenSearch, and Grafana
  stack remain explicit support container resources.
- `WithReference`, endpoint expressions, health checks, and `WaitFor` model the
  topology while preserving image-specific environment contracts.
- Only frontend-proxy ports `8080` and `10000`, and Prometheus port `9090`, are
  treated as stable host contracts.

## Highest-Risk Areas

1. Collector configuration merge order, endpoint matrix, root execution, and
   host/Docker socket mounts.
2. Kafka advertised listeners, real readiness, topic auto-creation, consumer
   evidence, and telemetry.
3. OpenSearch readiness timing, ulimits, memory, and Collector log export.
4. PostgreSQL initialization SQL, custom users/schemas, credentials, and
   compatibility with an Aspire native resource.
5. Envoy frontend-proxy routes and the stable ingress contract.
6. Image reproducibility because the resolved application tags use
   `latest-*`.
7. Full-stack startup under the no-swap DevBox memory constraint.

## Kafka Strategy

Use the same instrumented single-broker KRaft container image. Preserve broker
port `9092`, controller port `9093`, topic auto-creation, replication factor
one, Java/JMX instrumentation, and an Aspire-resolvable advertised listener.

Add a real TCP readiness check and require checkout, accounting, and
fraud-detection to wait for it. Validate order production, accounting
consumption, fraud-detection behavior, and Collector Kafka metrics separately.

## Observability Strategy

Preserve the source observability stack in addition to the Aspire dashboard.
Keep the Collector's base, full, observability, and extras configuration order
and retain all receivers, processors, exporters, and signal pipelines.

Validate:

- traces in Jaeger;
- OTLP-delivered application and infrastructure metrics in Prometheus;
- telemetry logs in OpenSearch;
- Grafana health and provisioning;
- Kafka, PostgreSQL, Valkey, NGINX, Docker, host, HTTP, and ad metrics;
- expected profile/firepit and transient host warnings against the baseline.

## Baseline Limitations Retained

The strategy explicitly retains these comparison criteria:

- OpenSearch startup timing issue;
- fraud-detection flagd resolver instability;
- small Load Generator HTTP 500 percentage;
- optional firepit exporter warning;
- transient host process scrape warnings;
- temporary Kafka telemetry/export startup errors;
- accounting topic-creation race;
- memory and startup timing sensitivity.

## Stage C Recommendation

Proceed to Stage C after selecting an image pinning policy and approving the
configuration-assets approach. Implement in dependency layers with partial
build and startup stop points. Do not begin full-stack validation until the
infrastructure, Kafka, observability backends, and Collector each pass their
targeted startup checks.

## Final Stage B Status

**PASS**

The strategy, complete resource mapping, implementation sequence, validation
approach, risks, and readiness criteria are sufficient to begin Stage C.

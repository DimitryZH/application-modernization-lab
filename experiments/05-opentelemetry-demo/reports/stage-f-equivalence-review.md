# Stage F: Functional and Operational Equivalence Review

## Result

**PASS with documented differences and baseline limitations**

The Experiment 05 Aspire deployment represents all 29 services from the
resolved four-layer Docker Compose deployment and preserves the primary
storefront, Kafka, and observability behavior validated in Stage A. No
unresolved Aspire-specific migration failure was found.

## Comparison Basis

- Upstream baseline commit:
  `b5320139de38b789654a9653d5c4fda441b5cb8f`
- Compose baseline: Stage A
- Aspire implementation: Stages C.1 through C.5
- Aspire runtime evidence: Stage D
- Aspire observability evidence: Stage E

## Service Coverage

| Measure | Compose baseline | Aspire result | Classification |
| --- | ---: | ---: | --- |
| Resolved services | 29 | 29 | Equivalent |
| Running resources at stable validation point | 29 | 29 | Equivalent |
| Intentionally omitted services | 0 | 0 | Equivalent |
| Immutable image records | Baseline runtime images | 29 image-lock entries | Equivalent or improved |

The Aspire AppHost uses explicit container resources to preserve the exact
polyglot images, commands, configuration, and internal endpoint contracts. The
Aspire dashboard supplements rather than replaces the upstream observability
backends.

## Endpoint and Functional Workflow Comparison

| Capability | Compose baseline | Aspire result | Classification |
| --- | --- | --- | --- |
| Storefront and routed UIs | Required endpoints returned HTTP 200 | Same required endpoints returned HTTP 200 | Equivalent |
| Prometheus health | HTTP 200 | HTTP 200 | Equivalent |
| Product browse and detail | Available | Product API returned 10 products and detail page returned HTTP 200 | Equivalent |
| Cart | Available | Cart read and generated cart additions succeeded | Equivalent |
| Checkout | Produced orders | Recovered from one startup race and produced orders | Equivalent with documented startup behavior |
| Accounting | Consumed orders | Consumed generated order details | Equivalent |
| Load generation | Active with approximately 4 percent HTTP 500 responses | Active with approximately 6.8 percent failures in the observed window | `BASELINE_LIMITATION` |

## Kafka and Messaging Comparison

Both deployments used the same instrumented single-broker KRaft image and
preserved the broker/controller listener model, topic auto-creation, the
`orders` producer path, and accounting consumption. Aspire validation found
the `orders` and `__consumer_offsets` topics, accounting consumption evidence,
Kafka metrics, and Kafka logs.

Checkout required the Compose `restart: unless-stopped` behavior to recover
from an early producer initialization race. Preserving this policy is a
`RESOLVED_MIGRATION_ISSUE`, not a functional difference in the stable runtime.
Fraud detection reproduced its baseline flagd resolver restart loop.

## Observability Comparison

| Signal or backend | Compose baseline | Aspire result | Classification |
| --- | --- | --- | --- |
| Jaeger | 17 services | 19 services; checkout trace covered 11 services | Equivalent or improved |
| Prometheus | Application and infrastructure metrics | 391 metric names with representative active series | Equivalent |
| OpenSearch | OpenTelemetry log index | More than 33,000 service-attributed documents | Equivalent |
| Grafana | Healthy | Healthy; 3 datasources and 8 dashboards | Equivalent with documented plugin limitation |
| Collector | Primary pipelines active with warnings | Four-layer config and primary pipelines active with baseline warnings | Equivalent |
| Kafka telemetry | Available after startup recovery | Metrics and logs available after startup recovery | Equivalent |

The Grafana OpenSearch plugin health check reported `Index not found:
otel-logs-*`, while direct and proxied OpenSearch queries succeeded. This is an
`OBSERVABILITY_LIMITATION`, not a broken signal path.

## Aspire-Specific Fixes

| Issue | Resolution | Classification |
| --- | --- | --- |
| Distroless frontend image cannot execute the Compose shell health command | Modeled the frontend endpoint as HTTP and used an Aspire HTTP health check | `RESOLVED_MIGRATION_ISSUE` |
| Checkout and fraud-detection restart behavior was initially absent | Preserved `restart: unless-stopped` | `RESOLVED_MIGRATION_ISSUE` |
| Restrictive DevBox checkout permissions blocked non-root config readers | Corrected runtime asset permissions to the documented contract | `ENVIRONMENT_FAILURE` |

## Known Limitations and Issue Classification

| Issue | Classification | Equivalence impact |
| --- | --- | --- |
| Fraud-detection flagd resolver restart loop | `SOURCE_LIMITATION` / `BASELINE_LIMITATION` | Reproduced in both deployments |
| Load Generator HTTP 500 percentage | `BASELINE_LIMITATION` | Reproduced; exact percentage varied |
| OpenSearch slow readiness | `ENVIRONMENT_FAILURE` / `BASELINE_LIMITATION` | Extended readiness required in both deployments |
| Optional firepit exporter warning | `OBSERVABILITY_LIMITATION` / `BASELINE_LIMITATION` | Primary signals unaffected |
| Transient host process scrape warnings | `OBSERVABILITY_LIMITATION` / `BASELINE_LIMITATION` | Host metrics remained available |
| Transient Kafka telemetry export errors | `BASELINE_LIMITATION` | Recovered after Collector readiness |
| Grafana OpenSearch health-check false negative | `OBSERVABILITY_LIMITATION` | Queries and log path remained functional |
| Collector host filesystem and Docker socket mounts | `DOCUMENTED_DIFFERENCE` | Appropriate only for local experiment validation |
| Transitive `MessagePack 2.5.192` `NU1903` warning | `DOCUMENTED_DIFFERENCE` | Build passes; production dependency risk remains |

No issue was classified as `MIGRATION_FAILURE`.

## Operational Comparison

Aspire centralizes the resolved topology, parameter references, image digests,
resource dependencies, and health behavior in one AppHost. It does not make
the upstream demo production-ready: startup remains resource-sensitive, state
is non-persistent, the Collector uses local host integrations, and the known
source/runtime limitations remain.

After the validation VM was restarted, Docker restart policies automatically
started only `checkout` and the unstable `fraud-detection`; the other 27
containers remained exited. Final cleanup stopped those two containers and
removed all 29 Experiment 05 containers while preserving images and volumes.

## Equivalence Verdict

**PASS with documented differences and baseline limitations**

The Aspire implementation achieves functional and operational equivalence for
the experiment's required storefront, messaging, and observability paths.
Remaining limitations are baseline, source, environment, observability, or
documented operational differences rather than unresolved migration failures.

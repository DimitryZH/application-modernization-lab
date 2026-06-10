# Stage A: Source Exploration and Compose Baseline

## Result

**PASS with documented baseline limitations**

Stage A established a reproducible source and architecture baseline for the official full OpenTelemetry Demo deployment on the existing DevBox. All required user interfaces and the primary traces, metrics, logs, Kafka, and load-generation paths were validated.

The baseline is not fully error-free. Its limitations are source or environment behaviors observed before any Aspire migration and must be used as comparison evidence in later stages.

## Scope and Safety

- Upstream repository: `https://github.com/open-telemetry/opentelemetry-demo.git`
- Validated commit: `b5320139de38b789654a9653d5c4fda441b5cb8f`
- Upstream working tree: clean
- Aspire migration: not started
- Upstream source modifications: none
- New cloud resources: none
- New public exposure: none
- Validation access: DevBox localhost through existing private access

## Deployment Result

The official full deployment uses four Compose layers and resolves to 29 services on one Compose network with no named volumes.

The official `make start` failed twice while waiting for a newly recreated OpenSearch container to become healthy. OpenSearch later became healthy without OOM evidence. Continuing the same full Compose deployment without another forced recreation started all dependent services.

Final observed state:

- 29 running containers;
- 0 containers with Docker health state `unhealthy`;
- 0 exited containers;
- Kafka healthy;
- OpenSearch healthy;
- frontend healthy;
- approximately 4.2 GiB host memory used and 3.5 GiB available;
- no swap configured.

## Endpoint Validation

| Validation | Result |
| --- | --- |
| Web Store | HTTP 200 |
| Grafana | HTTP 200 |
| Jaeger | HTTP 200 |
| Load Generator | HTTP 200 |
| Feature Flags | HTTP 200 |
| Telemetry documentation | HTTP 200 |
| Prometheus health | HTTP 200 |

## Observability Validation

| Signal or component | Evidence | Result |
| --- | --- | --- |
| Traces | Jaeger API listed 17 services | PASS |
| Metrics | Prometheus metric-name API contained application and infrastructure metrics | PASS |
| Logs | OpenSearch contained an OpenTelemetry logs index | PASS |
| Grafana | Health API reported database status `ok` | PASS |
| Collector | Running and routing signals, with documented optional-exporter and host-scrape warnings | PASS with limitations |
| Load generation | Running and generating telemetry | PASS with baseline failures |

Prometheus had no scrape targets because the Collector writes metrics through Prometheus's OTLP endpoint. This is expected for the inspected observability configuration.

## Kafka Validation

- Kafka reached healthy state.
- Checkout produced order events.
- Accounting connected to Kafka and consumed generated orders.
- The Collector full configuration included Kafka metrics collection.
- Accounting initially observed the auto-created `orders` topic as unavailable before recovering.
- Fraud-detection remained unstable because of a flagd resolver error.

## Baseline Limitations

1. The official force-recreate startup path can time out before OpenSearch becomes healthy.
2. `fraud-detection` is in a restart loop caused by an upstream flagd gRPC resolver error.
3. The Load Generator reports approximately 4 percent HTTP 500 failures while the storefront remains available.
4. The optional `firepit` exporter is unresolved and produces Collector warnings.
5. Host process scraping can report transient missing-process errors.
6. Kafka telemetry export fails temporarily before the Collector starts.
7. The deployment is sensitive to memory and startup timing on a no-swap DevBox.

These findings are baseline source or environment limitations. They are not Aspire migration failures.

## Artifacts

- `docs/source-project-overview.md`
- `docs/compose-topology.md`
- `docs/observability-architecture.md`
- `docs/kafka-and-messaging.md`
- `docs/failure-scenarios.md`
- `docs/exploration-notes.md`
- `reports/stage-a-source-exploration-and-compose-baseline.md`

## Runtime State

The full Compose stack remains running on the existing DevBox for follow-up inspection. It is not publicly exposed.

## Next Step

Proceed to Stage B: define an Aspire migration strategy that preserves the four-layer resolved topology, startup dependencies, Kafka behavior, feature flags, and observability signal paths while treating the documented baseline limitations as comparison criteria.

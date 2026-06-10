# Compose Topology

## Full Deployment Composition

The official full deployment is assembled in this order:

1. `compose.yaml`
2. `compose.full.yaml`
3. `compose.observability.yaml`
4. `compose.extras.yaml`

The official `make start` target applies those files with `.env` and `.env.override`, forces container recreation, removes orphans, and starts the deployment in detached mode.

The resolved full topology contains:

- 29 services;
- one default Compose network named `opentelemetry-demo`;
- no named Compose volumes;
- 28 services with `unless-stopped` restart behavior;
- one service with `always` restart behavior.

## Primary Request Path

```text
load-generator or user
  -> frontend-proxy
  -> frontend
  -> application services
  -> PostgreSQL, Valkey, Kafka, and feature flags as required
```

`frontend-proxy` is the stable entry point for the storefront and supporting user interfaces. The Stage A validation used only DevBox-local endpoints and did not add public exposure.

## Stable User Interfaces

| Interface | DevBox-local URL |
| --- | --- |
| Web Store | `http://localhost:8080` |
| Grafana | `http://localhost:8080/grafana/` |
| Jaeger | `http://localhost:8080/jaeger/ui` |
| Load Generator | `http://localhost:8080/loadgen/` |
| Feature Flags | `http://localhost:8080/feature/` |
| Telemetry documentation | `http://localhost:8080/telemetry/` |
| Prometheus health | `http://localhost:9090/-/healthy` |

Other service ports are dynamically published by Compose and should not be treated as stable migration contracts.

## Dependency Groups

- Data: PostgreSQL backs application data; Valkey backs cart state.
- Messaging: checkout produces order events to Kafka; accounting and fraud-detection consume them.
- Feature flags: flagd supplies runtime controls to services and the feature-flag UI.
- Telemetry: services export OTLP data to the OpenTelemetry Collector.
- Observability backends: Jaeger stores and queries traces, Prometheus stores metrics, OpenSearch stores logs, and Grafana provides dashboards.

## Runtime Resource Pressure

The DevBox has approximately 7.8 GiB RAM and no swap. During Stage A, the full stack used approximately 4.2 GiB host memory, with approximately 3.5 GiB still available.

Notable configured container memory limits include:

- load-generator: 1500 MB;
- Jaeger: 1200 MB;
- OpenSearch: 1 GB;
- Kafka: 620 MB;
- recommendation: 500 MB.

The migration must preserve resource awareness and avoid assuming that all services become ready within a short fixed startup window.

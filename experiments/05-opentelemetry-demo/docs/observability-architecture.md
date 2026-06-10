# Observability Architecture

## Signal Flow

```text
instrumented services and infrastructure receivers
  -> OpenTelemetry Collector
  -> Jaeger for traces
  -> Prometheus OTLP endpoint for metrics
  -> OpenSearch for logs
  -> debug and optional firepit exporters
  -> Grafana and Jaeger user interfaces
```

## Collector Inputs

The base Collector configuration accepts OTLP over gRPC and HTTP and includes receivers for:

- Docker statistics;
- host metrics;
- HTTP checks;
- NGINX;
- PostgreSQL;
- Prometheus-format service metrics;
- Valkey.

It also includes a span-to-metrics connector, memory limiting, resource detection, and signal sanitization. The full configuration adds Kafka metrics collection.

## Collector Outputs

The observability configuration routes:

- traces to Jaeger;
- metrics to the Prometheus OTLP write endpoint;
- logs to OpenSearch;
- profiles and additional signals to configured debug or optional exporters.

Prometheus intentionally had no scrape targets in Stage A because application metrics were delivered through its OTLP endpoint. Its metric-name API contained application, database, container, and runtime metrics.

## Stage A Evidence

- Grafana health API reported database status `ok`.
- Jaeger API reported traces for 17 services after load generation.
- Prometheus contained application and infrastructure metric names.
- OpenSearch contained the `otel-logs-2026-06-10` index.
- The Load Generator was running and continuously produced traffic.

## Known Observability Limitations

- The Collector repeatedly attempted to resolve the optional `firepit` exporter, which was not present in the full Compose deployment.
- Host process scraping occasionally reported a process disappearing between discovery and read operations.
- Kafka emitted telemetry export errors before the Collector became available.
- OpenSearch and Kafka need significant warm-up time before dependent services can start reliably.
- The Collector mounts the Docker socket and host filesystem. An Aspire migration must explicitly review these privileged host integrations.

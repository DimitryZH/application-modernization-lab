# Stage E: Observability Validation

## Result

**PASS with documented baseline and datasource limitations**

The running Experiment 05 Aspire deployment provides working traces, metrics,
and logs through the expected observability backends. The Collector loaded the
preserved four-layer configuration, all primary signal pipelines processed
data, Kafka and infrastructure telemetry were present, and the results were
comparable to or stronger than the Stage A Compose baseline.

No AppHost or configuration change was required during Stage E.

## Stack State

- Starting commit: `00b3cfa test(experiment-05): validate full Aspire runtime`
- Working tree before Stage E: clean
- Existing Aspire deployment reused without restart
- 29 containers running
- 0 unhealthy containers
- 0 exited containers
- Kafka: healthy
- OpenSearch: healthy
- Storefront, Jaeger, and Prometheus endpoints: reachable

## Jaeger Validation

**Result: PASS**

- Jaeger UI and API were reachable through frontend-proxy.
- Jaeger listed 19 services, compared with 17 during Stage A.
- Representative services included:
  - `frontend`
  - `frontend-web`
  - `frontend-proxy`
  - `checkout`
  - `accounting`
  - `product-catalog`
  - `product-reviews`
  - `cart`
  - `payment`
  - `shipping`
- The API returned 1,000 frontend traces at the query limit.
- The API returned 35 checkout traces.
- A representative checkout trace contained 46 spans across 11 services.
- Checkout traces included operations for the storefront checkout API, cart,
  currency, payment, product catalog, shipping, quote, email, flagd, and
  PostgreSQL paths.

Kafka did not appear as a Jaeger service. Kafka telemetry was instead validated
through metrics and logs, matching the deployment's instrumentation behavior.

## Prometheus Validation

**Result: PASS**

- Prometheus health endpoint returned HTTP 200.
- Prometheus exposed 391 metric names.
- Application telemetry was present through HTTP and RPC metric families.
- Instant queries returned active series for:

| Metric | Active series or evidence |
| --- | --- |
| `http_server_request_duration_seconds_count` | 9 series |
| `kafka_brokers` | 1 series, value `1` |
| `kafka_consumer_group_members` | 1 series |
| `kafka_consumer_group_lag_sum_ratio` | 1 series |
| `postgresql_backends` | 2 series |
| `redis_commands_processed_total` | 1 series |
| `nginx_requests_total` | 1 series |
| `container_cpu_utilization_ratio` | 29 series |
| `system_cpu_utilization_ratio` | 40 series |
| `otelcol_exporter_sent_spans_total` | 3 series |

Additional metric families included Kafka broker/topic/consumer telemetry,
PostgreSQL database metrics, NGINX metrics, Docker/container metrics, host and
process metrics, and Collector self-telemetry.

Prometheus had zero scrape targets. This is expected and matches Stage A:
application and infrastructure metrics are collected by the Collector and
delivered through Prometheus's OTLP receiver.

## OpenSearch Validation

**Result: PASS**

- OpenSearch cluster health was `yellow`, which is expected for the
  single-node deployment with an unassigned replica.
- The telemetry log index `otel-logs-2026-06-13` existed.
- More than 33,000 log documents contained `resource.service.name`.
- Representative log-producing services included:
  - `frontend-proxy`
  - `product-catalog`
  - `otelcol-contrib`
  - `product-reviews`
  - `recommendation`
  - `load-generator`
  - `cart`
  - `kafka`
  - `checkout`
  - `accounting`
- The index was accessible both directly and through the Grafana OpenSearch
  datasource proxy.

No sensitive log bodies were stored in this report.

## Grafana Validation

**Result: PASS with documented datasource health-check limitation**

- Grafana health API reported database status `ok`.
- Three datasources were provisioned:
  - Prometheus
  - Jaeger
  - OpenSearch
- Prometheus datasource health: working.
- Jaeger datasource health: working.
- OpenSearch datasource proxy: successfully listed the telemetry log index.
- Eight dashboards were provisioned, including:
  - APM Dashboard
  - Demo Dashboard
  - OpenTelemetry Collector
  - PostgreSQL
  - Linux host metrics
  - Image Provider NGINX Metrics
  - Cart Service Exemplars
  - Spanmetrics Demo Dashboard

The Grafana OpenSearch plugin health endpoint returned `Index not found:
otel-logs-*`, while the same datasource proxy successfully listed
`otel-logs-2026-06-13` and direct OpenSearch queries returned log data. This is
classified as a Grafana plugin health-check false negative, not a broken
Collector-to-OpenSearch path.

Grafana also logged alert-template evaluation errors and expected SMTP
notification failures because SMTP is not configured. Provisioned dashboards
and datasource queries remained available. The provisioned assets are
unchanged from upstream, so these are classified as source/runtime limitations.

## Collector Validation

**Result: PASS with baseline warnings**

- Collector container remained running with zero restarts.
- Collector ran as `0:0`, preserving the required host and Docker access.
- Collector configuration and host integration mounts were read-only.
- Configuration merge order was preserved:
  1. `otelcol-config.yml`
  2. `otelcol-config-full.yml`
  3. `otelcol-config-observability.yml`
  4. `otelcol-config-extras.yml`
- OTLP gRPC and HTTP receivers started.
- Collector reported `Everything is ready. Begin running and processing data.`
- Active receiver coverage included:
  - OTLP
  - Docker stats
  - frontend-proxy HTTP check
  - host metrics
  - NGINX
  - Redis/Valkey
  - PostgreSQL
  - Kafka metrics
  - span metrics
- Active backend exporters included:
  - Jaeger for traces
  - Prometheus OTLP for metrics
  - OpenSearch for logs
  - debug exporters for validation
- Collector debug output showed traces, metrics, and logs.
- Collector self-metrics showed sent spans, metric points, and log records.
- `otelcol_exporter_send_failed_spans_total` had value `0`.

The optional firepit profile exporter remains configured but no profile-path
regression blocked the primary traces, metrics, or logs pipelines.

## Kafka and Messaging Telemetry

**Result: PASS with baseline startup behavior**

- Kafka remained healthy.
- Kafka topics included `orders` and `__consumer_offsets`.
- Kafka broker, consumer-group membership, and lag metric series existed in
  Prometheus.
- OpenSearch contained Kafka logs.
- Accounting logs confirmed consumed order details.
- Checkout remained running after one startup-race restart.
- Early Kafka telemetry export errors occurred before Collector DNS became
  available and then recovered, matching Stage A.

## Stage A Comparison

| Stage A observation | Stage E Aspire result | Classification |
| --- | --- | --- |
| Jaeger listed 17 services | Jaeger listed 19 services | Equivalent or improved |
| Application and infrastructure metrics present | 391 metric names and active representative series | Equivalent |
| Prometheus had zero scrape targets due to OTLP delivery | Zero scrape targets; OTLP metric data present | Equivalent |
| OpenSearch telemetry log index present | Log index present with more than 33,000 service-attributed documents | Equivalent |
| Grafana health database status `ok` | Database status `ok`; datasources and dashboards provisioned | Equivalent with plugin health limitation |
| Collector routed traces, metrics, and logs | All three primary signals processed and exported | Equivalent |
| Fraud-detection flagd resolver instability | Restart loop reproduced | Known baseline limitation |
| Approximately 4 percent Load Generator failures | Approximately 6.8 percent during the observed startup/runtime window | Baseline limitation; no zero-failure requirement |
| Host process scrape warnings | Reproduced | Known baseline limitation |
| Transient Kafka telemetry export errors | Reproduced before Collector readiness, then recovered | Known baseline limitation |
| OpenSearch readiness sensitivity | Extended readiness required; healthy afterward | Known baseline limitation |

## Issue Classification

| Issue | Classification | Impact |
| --- | --- | --- |
| Fraud-detection flagd resolver restart loop | Known Stage A source limitation | Fraud detection remains unstable |
| Load Generator HTTP 500 failures | Known Stage A source/runtime limitation | Storefront and telemetry remain available |
| Host process scrape race warnings | Known Stage A Collector limitation | Host metrics continue to be exported |
| Early Kafka OTLP DNS/export errors | Known Stage A startup limitation | Kafka telemetry recovers after Collector readiness |
| OpenSearch slow readiness | Known Stage A environment limitation | Backend becomes healthy after extended startup |
| Grafana OpenSearch health-check false negative | Newly documented Grafana plugin limitation | Datasource proxy and direct log queries work |
| Grafana alert-template and SMTP errors | Upstream configuration/runtime limitation | Dashboards and datasource queries work |

No new Aspire wiring regression was found.

## Runtime State

The Aspire AppHost and all 29 containers remain running for follow-up
inspection. The active DevBox continues consuming CPU and memory and continues
to incur its normal VM cost while it remains running.

## Stage E Status

**PASS with documented baseline and datasource limitations**

The Aspire deployment preserves the expected observability behavior for
traces, metrics, logs, Grafana provisioning, Collector pipelines, and Kafka
telemetry. Stage F can proceed with the functional and operational equivalence
review.

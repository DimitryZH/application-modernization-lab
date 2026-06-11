# Aspire Resource Mapping

## Mapping Basis

This mapping covers every service in the resolved full deployment produced by
`compose.yaml`, `compose.full.yaml`, `compose.observability.yaml`, and
`compose.extras.yaml` at upstream commit
`b5320139de38b789654a9653d5c4fda441b5cb8f`.

The primary Stage C approach is to use pinned prebuilt images. The Compose build
context is recorded because each demo image can be rebuilt from the pinned
upstream clone, but Aspire Dockerfile resources are a fallback rather than the
default full-migration path.

Dynamic means Compose exposes the container port on an unspecified host port.
Only `frontend-proxy` ports `8080` and `10000`, and Prometheus port `9090`, are
stable host-port contracts.

## Full Service Mapping

| Compose service | Role | Image or build context | Ports | Dependencies | Environment and configuration notes | Proposed Aspire representation | Migration risk | Validation method |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| accounting | Kafka order consumer and PostgreSQL writer | `ghcr.io/open-telemetry/demo:latest-accounting`; `src/accounting/Dockerfile` | None | Kafka healthy; Collector started | `KAFKA_ADDR`; parameterized PostgreSQL connection string; OTLP HTTP | Aspire container resource; Dockerfile fallback | High: broker readiness, DB initialization, and consumer evidence | Confirm connection, consumed orders, and accounting rows/traces |
| ad | Ads gRPC service and Prometheus metrics source | `ghcr.io/open-telemetry/demo:latest-ad`; `src/ad/Dockerfile` | Dynamic `9555`, `9465` | flagd; Collector | flagd address; OTLP HTTP; Java agent; ad metrics port | Aspire container resource; Dockerfile fallback | Medium: Java agent and separate metrics endpoint | Frontend ads, gRPC reachability, Collector ad scrape, traces/logs |
| astronomy-db | PostgreSQL application and monitoring database | `postgres:17.8` | Dynamic `5432` | None | Password parameter; `pg_stat_statements`; initialization SQL creates schemas, users, and seed data | Aspire native PostgreSQL resource with exact image/init contract; explicit container fallback | High: init SQL, custom users/passwords, command, and native-resource differences | Readiness query; schemas/data; product catalog, reviews, and accounting DB use; Collector metrics |
| cart | Cart gRPC service | `ghcr.io/open-telemetry/demo:latest-cart`; `src/cart/src/Dockerfile` | Dynamic `7070` | Valkey; flagd; Collector | `VALKEY_ADDR`; ASP.NET URL; OTLP and flagd settings | Aspire container resource; Dockerfile fallback | Medium: Redis-compatible endpoint syntax and feature flags | Add/read cart through storefront; traces and Valkey metrics |
| checkout | Checkout orchestrator and Kafka producer | `ghcr.io/open-telemetry/demo:latest-checkout`; `src/checkout/Dockerfile` | Dynamic `5050` | cart, currency, email, payment, product-catalog, shipping, flagd, Collector; Kafka healthy | Six service addresses; `KAFKA_ADDR`; Go memory limit; OTLP | Aspire container resource; Dockerfile fallback | High: broad dependency fan-out and Kafka producer path | Complete checkout; confirm order event, accounting consumption, and distributed trace |
| currency | Currency gRPC service | `ghcr.io/open-telemetry/demo:latest-currency`; `src/currency/Dockerfile` | Dynamic `7001` | Collector | OTLP; IPv6 flag; image version | Aspire container resource; Dockerfile fallback | Low: endpoint and C++ telemetry settings | Currency conversion through storefront and trace |
| email | Email gRPC service | `ghcr.io/open-telemetry/demo:latest-email`; `src/email/Dockerfile` | Dynamic `6060` | Collector | OTLP HTTP; production mode; flagd address variables | Aspire container resource; Dockerfile fallback | Low: no explicit flagd dependency despite address settings | Checkout email call and telemetry |
| flagd | Feature flag service | `ghcr.io/open-feature/flagd:v0.14.2` | Dynamic `8013`, `8016` | None | Mount flag definitions; file URI command; OTLP metrics to Collector | Aspire container resource | High: shared writable flag file and known fraud-detection resolver behavior | Flag evaluation, OFREP endpoint, UI mutation, and failure-control checks |
| flagd-ui | Feature flag management UI | `ghcr.io/open-telemetry/demo:latest-flagd-ui`; `src/flagd-ui/Dockerfile` | Dynamic `4000` | flagd; Collector | Shared flag data mount; parameterized `SECRET_KEY_BASE`; OTLP HTTP | Aspire container resource; Dockerfile fallback | High: secret handling and shared writable mount | `http://localhost:8080/feature/`; update and restore a test flag |
| fraud-detection | Kafka order consumer | `ghcr.io/open-telemetry/demo:latest-fraud-detection`; `src/fraud-detection/Dockerfile` | None | Kafka healthy; Collector started | Kafka and flagd addresses; Java agent; messaging telemetry settings | Aspire container resource; Dockerfile fallback | High: known upstream flagd resolver restart loop | Record runtime stability, Kafka subscription, logs, and comparison with baseline |
| frontend | Storefront application | `ghcr.io/open-telemetry/demo:latest-frontend`; `src/frontend/Dockerfile` | Dynamic `8080` | ad, cart, checkout, currency, product-catalog, quote, recommendation, shipping, Collector, image-provider, flagd | All backend addresses; browser OTLP endpoint; frontend-web telemetry | Aspire container resource; Dockerfile fallback | High: many endpoints, browser telemetry, and explicit health check | Health check; browse/cart/checkout; browser and server traces |
| frontend-proxy | Envoy ingress and routed UI gateway | `ghcr.io/open-telemetry/demo:latest-frontend-proxy`; `src/frontend-proxy/Dockerfile` | Stable `8080`, `10000` | frontend healthy; load-generator, flagd-ui, telemetry-docs, Grafana, Jaeger started | Envoy template consumes all routed service addresses; OTLP gRPC/HTTP; optional firepit route | Aspire container resource; Dockerfile fallback | High: stable public contract and route/address matrix | All routed HTTP endpoints, Envoy admin, access logs, and proxy traces |
| grafana | Dashboard UI | `grafana/grafana:13.0.1` | Dynamic `3000` | None | Mount `grafana.ini` and provisioning tree; install OpenSearch plugin | External/observability support container resource | High: plugin availability and provisioned datasource addresses | Routed Grafana HTTP 200; health API; datasource and dashboard checks |
| image-provider | NGINX image service and metrics source | `ghcr.io/open-telemetry/demo:latest-image-provider`; `src/image-provider/Dockerfile` | Dynamic `8081` | Collector | Collector gRPC address; NGINX status scraped by Collector | Aspire container resource; Dockerfile fallback | Medium: NGINX metrics and proxy route | Storefront images, `/status`, metrics, and traces |
| jaeger | Trace backend and UI | `quay.io/jaegertracing/jaeger:2.14.1` | Dynamic `16686`, `4317` | None | Mount Jaeger config; Prometheus integration; OTLP gRPC ingest | External/observability support container resource | High: config mount, Collector export, and routed UI prefix | Routed UI HTTP 200; API service list and trace queries |
| kafka | Instrumented single-broker KRaft message broker | `ghcr.io/open-telemetry/demo:latest-kafka`; `src/kafka/Dockerfile` | Internal `9092`, `9093`; no host publication | None | Advertised listeners must use Aspire-resolvable name; Java/JMX instrumentation; heap limit | Aspire container resource using exact demo image | Critical: advertised listeners, readiness, topic auto-creation, telemetry | TCP readiness; broker/topic checks; checkout production; accounting and fraud consumer checks; Kafka metrics |
| llm | Local review-summary model service | `ghcr.io/open-telemetry/demo:latest-llm`; `src/llm/Dockerfile` | Dynamic `8000` | flagd | flagd address | Aspire container resource; Dockerfile fallback | Medium: same internal port as telemetry-docs and feature behavior | Product review summary call and flag behavior |
| load-generator | Locust workload and UI | `ghcr.io/open-telemetry/demo:latest-load-generator`; `src/load-generator/Dockerfile` | Dynamic `8089` | frontend; flagd | Storefront target; autostart/headless/user settings; OTLP; OFREP | Aspire container resource; Dockerfile fallback; optional low-resource mode only | High: 1500 MB limit, startup traffic, and baseline HTTP failures | Routed UI HTTP 200; active users; request/failure rate compared with baseline |
| opensearch | Telemetry log backend | `ghcr.io/open-telemetry/demo:latest-opensearch`; `src/opensearch/Dockerfile` | Dynamic `9200` | None | Single node; security disabled; heap settings; memlock/nofile ulimits | External/observability support container resource | Critical: slow readiness, ulimits, memory, and Collector dependency | Cluster health readiness; telemetry log index and query |
| otel-collector | Central telemetry router and infrastructure receiver | `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.151.0` | Dynamic `4317`, `4318` | Jaeger started; OpenSearch healthy | Four ordered configs; root user; read-only host filesystem and Docker socket; Kafka/PostgreSQL/Valkey/NGINX/ad receivers | External/observability support container resource | Critical: config merge order, privileged mounts, endpoint matrix, and signal completeness | Collector state/logs; traces, metrics, logs, profiles warnings, and all infrastructure receivers |
| payment | Payment gRPC service | `ghcr.io/open-telemetry/demo:latest-payment`; `src/payment/Dockerfile` | Dynamic `50051` | flagd; Collector | flagd, OTLP, and IPv6 settings | Aspire container resource; Dockerfile fallback | Medium: critical checkout dependency and failure flags | Successful checkout, payment failure flag, and traces |
| product-catalog | Catalog gRPC service backed by PostgreSQL | `ghcr.io/open-telemetry/demo:latest-product-catalog`; `src/product-catalog/Dockerfile` | Dynamic `3550` | astronomy-db; flagd; Collector | Parameterized DB URI; mounted `otel-config.yml`; Go memory limit | Aspire container resource; Dockerfile fallback | High: DB URI, initialization, mounted telemetry config | Product listing/data, DB query, failure flag, and traces |
| product-reviews | Reviews gRPC service backed by PostgreSQL and LLM | `ghcr.io/open-telemetry/demo:latest-product-reviews`; `src/product-reviews/Dockerfile` | Dynamic `3551` | astronomy-db, llm, product-catalog, Collector | Parameterized DB string and `OPENAI_API_KEY`; LLM/catalog/flagd addresses; GenAI telemetry | Aspire container resource; Dockerfile fallback | High: secrets, DB, LLM fallback, and GenAI telemetry | Review data and summary; DB query; no secret leakage; traces/logs |
| prometheus | Metrics backend with OTLP receiver | `quay.io/prometheus/prometheus:v3.9.1` | Stable `9090` | None | Mount config; OTLP receiver and exemplar storage enabled; no expected scrape targets | External/observability support container resource | High: OTLP ingestion must not be mistaken for scrape-based validation | `/-/healthy`; metric-name API; application/infrastructure metrics and exemplars |
| quote | Quote gRPC service | `ghcr.io/open-telemetry/demo:latest-quote`; `src/quote/Dockerfile` | Dynamic `8090` | Collector | OTLP HTTP; PHP instrumentation; IPv6 setting | Aspire container resource; Dockerfile fallback | Low: PHP instrumentation environment | Shipping quote path and telemetry |
| recommendation | Recommendation gRPC service | `ghcr.io/open-telemetry/demo:latest-recommendation`; `src/recommendation/Dockerfile` | Dynamic `9001` | product-catalog; flagd; Collector | Catalog and flagd addresses; Python telemetry | Aspire container resource; Dockerfile fallback | Medium: 500 MB limit and cache failure flag | Recommendations, cache flag behavior, and telemetry |
| shipping | Shipping gRPC service | `ghcr.io/open-telemetry/demo:latest-shipping`; `src/shipping/Dockerfile` | Dynamic `50050` | flagd; Collector | Quote address; OTLP; IPv6 setting | Aspire container resource; Dockerfile fallback | Medium: Compose omits explicit quote dependency despite runtime address | Shipping quote and checkout; slowdown flag; traces |
| telemetry-docs | Telemetry documentation UI | `ghcr.io/open-telemetry/demo:latest-telemetry-docs`; `src/telemetry-docs/Dockerfile` | Dynamic `8000` | None | Collector gRPC address and service name | Aspire container resource; Dockerfile fallback | Low: proxy route and Collector endpoint | `http://localhost:8080/telemetry/` HTTP 200 and content check |
| valkey-cart | Cart state store | `ghcr.io/valkey-io/valkey:9.0.2-alpine3.23` | Dynamic `6379` | None | Runs as `valkey`; no named volume in baseline | Aspire native Redis-compatible resource with exact Valkey image; explicit container fallback | Medium: native-resource image compatibility and no-persistence baseline | Readiness, cart persistence during run, and Collector Valkey metrics |

## Coverage Summary

- Resolved Compose services: **29**
- Services mapped: **29**
- Services intentionally omitted: **0**
- Default Stage C resources not started: **0**
- Native-resource candidates: `astronomy-db`, `valkey-cart`
- Exact container required: `kafka`
- External/observability support containers: `otel-collector`, `jaeger`,
  `prometheus`, `opensearch`, `grafana`

## Cross-Cutting Configuration

Stage C must model these cross-cutting contracts in addition to the row-level
mapping:

- common OTLP endpoint, metrics temporality, resource attributes, and service
  name settings;
- flagd host and port settings;
- custom service address formats;
- parameterized PostgreSQL credentials and connection strings;
- parameterized `OPENAI_API_KEY` and flagd UI secret;
- exact Collector config merge order;
- tracked configuration mounts;
- memory-aware startup sequencing;
- stable host ports only for frontend-proxy and Prometheus.

# Experiment 05 Full Aspire Migration Strategy

## Purpose

Define the engineering strategy for migrating the complete OpenTelemetry Demo
(Astronomy Shop) deployment from its four-layer Docker Compose model to a
.NET Aspire AppHost.

This is explicitly a **full-application migration strategy**, not a subset
migration. The target is all 29 services in the resolved Compose deployment,
including the application, data stores, Kafka, feature flags, load generation,
the OpenTelemetry Collector, and the observability backends.

## Scope

Stage C will reproduce the resolved combination of:

1. `compose.yaml`
2. `compose.full.yaml`
3. `compose.observability.yaml`
4. `compose.extras.yaml`

The migration must preserve service contracts, stable host endpoints,
dependency intent, configuration mounts, health behavior, and the traces,
metrics, logs, profiles, and Kafka paths established in Stage A.

## Migration Philosophy

- Treat the resolved Compose model, not any individual Compose layer, as the
  source of truth.
- Preserve behavior before optimizing for Aspire-native abstractions.
- Use Aspire references and endpoint expressions to remove hard-coded
  container DNS values where the existing image contract permits it.
- Preserve explicit environment variables when an image expects a custom
  address format that `WithReference` does not populate automatically.
- Prefer pinned prebuilt upstream images for the first full migration. This
  avoids making the AppHost depend on an external source clone and preserves
  the exact polyglot runtime artifacts validated in Stage A.
- Use Dockerfile resources only as a deliberate fallback when a prebuilt image
  cannot satisfy the migration contract.
- Introduce parameters for passwords, API keys, and application secrets. No
  local `.env` values are to be copied into tracked AppHost source.
- Use health checks and `WaitFor` only where readiness is meaningful. Process
  start is not equivalent to readiness for Kafka, OpenSearch, PostgreSQL, or
  user-facing services.
- Compare Aspire behavior with the documented baseline limitations instead of
  requiring an unrealistically error-free target.

## Full-Application Migration Goal

The Stage C AppHost must declare all 29 resolved services. No service may be
silently omitted. A service may be disabled in an explicit low-resource
developer mode only if the default full-validation mode starts it and the
difference is documented.

The full target includes:

- 16 application services;
- 8 platform and support services;
- 5 observability services.

## Non-Goals

- Rewriting or modernizing upstream application implementations.
- Changing the OpenTelemetry Demo's functional behavior or failure flags.
- Replacing Kafka with another broker.
- Replacing Jaeger, Prometheus, OpenSearch, Grafana, or the Collector with
  Aspire dashboard features.
- Making dynamic Compose host ports stable without a validation need.
- Adding production persistence, high availability, TLS, or cloud deployment.
- Fixing known upstream runtime defects as part of migration equivalence.
- Modifying the pinned upstream source or its Compose files.

## Major Migration Challenges

### Resolved multi-layer configuration

`checkout` and `otel-collector` are patched by later Compose layers, while
`frontend-proxy` gains observability dependencies. Stage C must encode the
final merged state. Translating only `compose.yaml` would omit Kafka consumers,
Kafka configuration, and observability exporters.

### Address and endpoint contracts

The images use custom variables such as `CART_ADDR`, `KAFKA_ADDR`,
`OTEL_EXPORTER_OTLP_ENDPOINT`, and `POSTGRES_HOST`. Stage C must inventory the
required address syntax for each image and populate it from Aspire endpoint
expressions. `WithReference` should express topology, but it is not a substitute
for image-specific environment variables.

### Startup and readiness

Compose has only three explicit health checks: `frontend`, `kafka`, and
`opensearch`. Many dependencies use `service_started`. Aspire must preserve the
observed tolerant startup behavior while adding readiness checks at the
critical boundaries:

- Kafka before checkout, accounting, and fraud detection;
- OpenSearch before the Collector log exporter;
- frontend before frontend-proxy and full endpoint validation;
- PostgreSQL before database-backed application validation.

OpenSearch and Kafka require generous startup time. Repeated recreation of slow
resources must be avoided during diagnosis.

### Configuration files and host integrations

The Collector, Grafana, Jaeger, Prometheus, flagd, PostgreSQL initialization,
product-catalog telemetry configuration, and Envoy proxy depend on files from
the upstream source tree. Stage C needs a tracked, reviewable configuration
asset strategy without editing upstream source.

The Collector also runs as root and mounts `/` and the Docker socket read-only
for host and container metrics. Those mounts are high-risk host integrations
and must be explicit, documented, and limited to local validation.

### Image reproducibility

Most resolved application image tags are `latest-*`. Before Stage C runtime
validation, record the exact image tags and digests used by the Stage A
baseline or select an explicit upstream version corresponding to the pinned
source commit. Image drift would invalidate equivalence conclusions.

### Resource pressure

The baseline uses approximately 4.2 GiB and has large configured limits for
load-generator, Jaeger, OpenSearch, Kafka, and recommendation. The DevBox has
no swap. Startup must be staged and validation timeouts must reflect this.

## Proposed Aspire Architecture

### AppHost layout

Create an Experiment 05 Aspire solution under
`experiments/05-opentelemetry-demo/aspire/` with an AppHost project and a
tracked configuration-assets directory. Keep source metadata and the pinned
upstream clone instructions separate from AppHost code.

Organize `Program.cs` declarations by dependency layer:

1. parameters and configuration assets;
2. data resources and feature flags;
3. Kafka;
4. observability backends;
5. Collector;
6. leaf application services;
7. orchestrating application services;
8. load generator, support UIs, and frontend-proxy.

Small local extension methods may group repeated OpenTelemetry environment
configuration, but the topology should remain easy to audit against the
29-row resource mapping.

### Resource representation

- Use Aspire native PostgreSQL and Redis-compatible resources for
  `astronomy-db` and `valkey-cart` only if their exact image versions,
  initialization behavior, endpoint names, and runtime contracts can be
  preserved. Otherwise fall back to explicit container resources.
- Use an Aspire container resource for the exact instrumented Kafka image.
  Do not replace it with an unverified native or community Kafka integration.
- Use Aspire container resources for the OpenTelemetry Collector and all
  observability backends.
- Use Aspire container resources with pinned prebuilt images for the
  application and support services.
- Treat Dockerfile resources as an explicit fallback or rebuild-validation
  mode, not the default Stage C path.

### Ports

Preserve these stable host contracts:

| Resource | Host contract |
| --- | --- |
| frontend-proxy | `8080` storefront and routed UIs |
| frontend-proxy admin | `10000` |
| prometheus | `9090` |

All other Compose ports are dynamically published implementation details.
Declare named internal endpoints for service discovery and expose host ports
only when required for validation or manual diagnostics.

### Dependencies

Use `WithReference` for declared service relationships and explicit
environment expressions for the upstream variable contracts. Use `WaitFor`
for readiness-sensitive edges. Avoid forcing every OTLP-producing service to
wait for the Collector if the baseline allows temporary telemetry export
failure and recovery.

## Observability Preservation Strategy

The Aspire dashboard is supplemental and must not replace the source
observability stack.

Preserve the Collector's ordered configuration merge:

1. base receivers and processors;
2. full Kafka metrics additions;
3. observability exporters;
4. extras customization stub.

Preserve these signal paths:

| Signal | Required path |
| --- | --- |
| Traces | services -> Collector -> Jaeger |
| Metrics | services/infrastructure -> Collector -> Prometheus OTLP endpoint |
| Logs | services -> Collector -> OpenSearch |
| Profiles | services -> Collector -> debug and optional firepit exporter |
| Meta telemetry | Collector -> Collector OTLP endpoint |

The Stage C configuration must retain Docker stats, host metrics, HTTP check,
NGINX, PostgreSQL, Valkey, ad Prometheus scrape, Kafka metrics, span metrics,
resource detection, memory limiting, and sanitization processors.

Mounting the Docker socket and host filesystem remains local-only and must be
reviewed before any non-experiment deployment. The unresolved optional
`firepit` exporter warning is a baseline limitation, not a reason to remove the
profiles pipeline silently.

## Kafka Preservation Strategy

Represent Kafka as an explicit container resource using the same instrumented
demo image and single-broker KRaft contract:

- broker listener `9092`;
- controller listener `9093`;
- one broker/controller;
- replication factor one;
- topic auto-creation enabled;
- Java agent and JMX instrumentation retained;
- broker address advertised through an Aspire-resolvable resource name.

Add a TCP readiness check equivalent to the Compose `nc -z kafka 9092` check.
`checkout`, `accounting`, and `fraud-detection` must wait for Kafka readiness,
not merely process start. Preserve `orders` topic auto-creation for the first
equivalence pass, then validate producer and both consumers independently.

The Collector must keep its Kafka metrics receiver. Expected temporary export
errors before Collector availability and the known fraud-detection flagd error
must be classified against the Stage A baseline.

## Validation Approach

### Static validation

- Confirm exactly 29 AppHost resources map to the 29 Compose services.
- Review every image, endpoint, dependency, environment contract, mount,
  command, health check, and stable host port against the resolved Compose
  output.
- Confirm secrets are parameters or external configuration.
- Confirm no upstream source or Compose file was modified.

### Build and startup validation

- Run `dotnet build`.
- Start infrastructure in dependency groups during implementation.
- Start the full AppHost without repeatedly recreating slow resources.
- Capture Aspire resource states and service logs.
- Allow extended readiness windows for OpenSearch, Kafka, and the full stack.

### Functional validation

- Verify HTTP 200 for Web Store, Grafana, Jaeger, Load Generator, Feature
  Flags, Telemetry documentation, and Prometheus health.
- Exercise storefront browse, cart, and checkout paths.
- Confirm the load generator remains active and record its failure percentage.
- Verify Kafka health, order production, and accounting consumption.
- Record fraud-detection behavior separately.

### Observability validation

- Confirm Jaeger lists application service traces.
- Confirm Prometheus contains application and infrastructure metrics through
  OTLP ingestion.
- Confirm OpenSearch contains telemetry log indices.
- Confirm Grafana health and provisioned data sources.
- Confirm Collector pipelines and Kafka metrics receiver are active.
- Compare warnings and failures with the Stage A baseline.

## Known Baseline Limitations

The following are comparison criteria and must not be automatically classified
as Aspire migration failures:

1. OpenSearch readiness can outlive the official startup timeout.
2. `fraud-detection` is unstable because of an upstream flagd resolver error.
3. Load Generator reports a small percentage of HTTP 500 responses.
4. The optional `firepit` exporter produces a resolution warning.
5. Host process scraping can produce transient warnings.
6. Kafka can report temporary telemetry export errors during startup.
7. Accounting can observe the `orders` topic before auto-creation completes.
8. Full startup is sensitive to memory and timing.

## Stage C Readiness Criteria

Stage C may begin when:

- all 29 services have an approved representation and validation method;
- image tag/digest pinning policy is selected;
- the configuration-assets location is selected;
- PostgreSQL and Valkey native-resource compatibility is confirmed or their
  container fallback is accepted;
- Kafka listener and endpoint-expression design is confirmed;
- Collector host-mount security implications are accepted for local use;
- secret parameters and non-secret settings are separated;
- stable ports and validation commands are agreed;
- baseline limitations remain available as explicit comparison criteria.

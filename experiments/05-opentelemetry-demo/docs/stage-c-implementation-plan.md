# Stage C Full AppHost Implementation Plan

## Objective

Implement a .NET Aspire AppHost that declares and starts all 29 services in the
resolved full OpenTelemetry Demo deployment while preserving the Stage A
functional, messaging, and observability contracts.

Stage C is implementation and build validation. Full runtime and observability
equivalence conclusions remain the focus of Stages D through F.

## Preconditions

- Approve the 29-service resource mapping.
- Select and record reproducible image tags or digests.
- Confirm the pinned upstream source remains available for configuration asset
  inspection, without modifying it.
- Decide whether tracked copies of required configuration assets may be added
  under the Aspire directory.
- Confirm native PostgreSQL and Redis-compatible resource behavior or accept
  their explicit container fallbacks.
- Accept the Collector's read-only Docker socket and host filesystem mounts for
  local experiment validation.

## Implementation Sequence

### 1. Create Aspire solution and AppHost

1. Create `experiments/05-opentelemetry-demo/aspire/` and the AppHost project.
2. Select the repository-consistent .NET and Aspire SDK versions.
3. Add configuration and parameter declarations without secret values.
4. Add a full-mode setting that starts all 29 resources by default.
5. Add small AppHost helper methods only for repeated, auditable environment
   and endpoint configuration.

**Stop point:** run `dotnet build`. Do not add service resources until the empty
AppHost builds.

### 2. Add infrastructure resources

1. Add `astronomy-db` using the Aspire PostgreSQL resource if the exact
   PostgreSQL 17.8 image, initialization SQL, command, users, and schemas can be
   preserved; otherwise use a container resource.
2. Add `valkey-cart` using a Redis-compatible Aspire resource customized to the
   exact Valkey image; otherwise use a container resource.
3. Add `flagd` with its flag-definition mount and command.
4. Add `llm`.
5. Add named internal endpoints and readiness checks.

**Stop point:** build, start this group, and verify PostgreSQL initialization,
Valkey readiness, and flagd evaluation. Stop only the partial AppHost instance,
not the Stage A Compose stack.

### 3. Add Kafka and messaging resources

1. Add `kafka` as an explicit container resource using the instrumented demo
   image.
2. Configure the KRaft broker and controller listeners using an
   Aspire-resolvable resource name.
3. Preserve heap, OpenTelemetry, and Java agent settings.
4. Add a TCP readiness check for broker port `9092`.
5. Preserve topic auto-creation.
6. Add `accounting` and validate its PostgreSQL and broker configuration.
7. Defer `fraud-detection` equivalence judgment until the full flagd path is
   wired.

**Stop point:** start the infrastructure and messaging group. Verify broker
readiness, topic creation behavior, accounting connection, and Kafka metrics
reachability before adding checkout as producer.

### 4. Add observability resources

1. Add `jaeger` with its config asset and OTLP gRPC endpoint.
2. Add `prometheus` with OTLP receiver and exemplar flags.
3. Add `opensearch` with heap settings, ulimits, and cluster health check.
4. Add `grafana` with its config and provisioning assets.
5. Add generous readiness windows for OpenSearch.

**Stop point:** start the observability backends and validate their direct
health endpoints. Do not require signal data yet.

### 5. Add OpenTelemetry Collector

1. Add `otel-collector` using the exact Collector Contrib image.
2. Preserve the four-file config order: base, full, observability, extras.
3. Mount all configuration assets.
4. Add the read-only Docker socket and host filesystem mounts explicitly.
5. Configure addresses for frontend-proxy, image-provider, Kafka, PostgreSQL,
   Valkey, and ad metrics.
6. Preserve the profile feature gate and root-user requirement.
7. Express startup dependencies on Jaeger and healthy OpenSearch.

**Stop point:** validate Collector configuration parsing and pipeline startup.
Confirm expected warnings are distinguished from configuration failures.

### 6. Add leaf application and support services

Add services with few downstream dependencies first:

- `ad`
- `currency`
- `email`
- `image-provider`
- `payment`
- `quote`
- `telemetry-docs`
- `product-catalog`
- `product-reviews`
- `recommendation`
- `shipping`
- `cart`
- `flagd-ui`

For each service:

1. Add its pinned prebuilt image.
2. Declare its internal endpoint.
3. Add `WithReference` relationships.
4. Populate the image's existing address and telemetry environment variables.
5. Preserve memory-sensitive runtime variables and configuration mounts.

**Stop point:** build after each logical group. Start the group and perform a
direct protocol or HTTP check before adding orchestrators.

### 7. Add orchestrating services

1. Add `checkout` with all six synchronous service addresses and Kafka.
2. Add `fraud-detection` and capture whether the known flagd resolver behavior
   reproduces.
3. Add `frontend` with all backend, image, flagd, Collector, and browser OTLP
   settings.
4. Preserve the frontend health check.
5. Add `load-generator` after frontend is reachable.
6. Add `frontend-proxy` last, with all routed target addresses and stable host
   ports `8080` and `10000`.

**Stop point:** verify frontend health before starting frontend-proxy. Verify
the storefront through port `8080` before enabling or assessing generated load.

### 8. Wire dependencies and environment variables

Perform a mapping audit against `aspire-resource-mapping.md`:

- every dependency is represented;
- every custom address variable has the required syntax;
- every OTLP endpoint is correct;
- every secret is a parameter;
- every required config asset is mounted;
- Kafka, PostgreSQL, and Valkey references resolve correctly;
- the Collector has the complete receiver/exporter address matrix.

Use `WaitFor` for health-sensitive dependencies. Preserve tolerant startup for
services that recover after their dependency becomes available.

**Stop point:** run a static 29-service count and configuration review before
full startup.

### 9. Preserve ports

1. Bind frontend-proxy storefront port to host `8080`.
2. Bind frontend-proxy admin port to host `10000`.
3. Bind Prometheus to host `9090`.
4. Name all internal endpoints.
5. Avoid fixed host ports for services that Compose publishes dynamically.

**Stop point:** verify no accidental host-port collisions and document any
required deviation.

### 10. Build

Run:

```bash
cd experiments/05-opentelemetry-demo/aspire
dotnet build
```

Resolve all AppHost and resource-model errors before full runtime validation.
Record the .NET SDK, Aspire package versions, and build result.

### 11. Runtime validation

1. Confirm the Stage A Compose stack state before starting Aspire to avoid port
   collisions. Do not stop it without approval.
2. Start the AppHost with an extended timeout.
3. Capture resource states and logs.
4. Wait for OpenSearch and Kafka readiness rather than restarting them.
5. Confirm all 29 declared resources reach the best expected state.
6. Classify the known fraud-detection behavior separately.

**Full-validation stop point:** if a critical infrastructure resource cannot
become ready after its documented extended window, stop diagnosis and preserve
logs before recreating resources.

### 12. Smoke tests

Validate:

```text
http://localhost:8080
http://localhost:8080/grafana/
http://localhost:8080/jaeger/ui
http://localhost:8080/loadgen/
http://localhost:8080/feature/
http://localhost:8080/telemetry/
http://localhost:9090/-/healthy
```

Then exercise browse, cart, and checkout behavior. Record Load Generator error
rate rather than requiring zero failures.

### 13. Observability and messaging checks

1. Query Jaeger for application service traces.
2. Query Prometheus metric names for application and infrastructure metrics.
3. Query OpenSearch for telemetry log indices.
4. Verify Grafana health and provisioned data sources.
5. Verify Kafka broker health and `orders` topic behavior.
6. Confirm checkout produces and accounting consumes order events.
7. Inspect fraud-detection separately.
8. Confirm Collector Kafka, PostgreSQL, Valkey, NGINX, Docker, host, HTTP, and ad
   metrics receivers.
9. Compare warnings with the Stage A limitation list.

## Required Implementation Records

During Stage C, maintain:

- exact image tags/digests;
- AppHost resource count;
- stable and diagnostic endpoints;
- parameter names and secret sources;
- configuration assets copied or referenced;
- build evidence;
- partial-start validation evidence;
- deviations from Compose behavior;
- unresolved risks for Stages D and E.

## Stage C Completion Criteria

Stage C is complete when:

- the AppHost declares all 29 mapped services;
- `dotnet build` passes;
- no secrets are committed;
- the full AppHost can be started for Stage D validation;
- stable ports and dependency wiring are implemented;
- known deviations and unresolved runtime issues are documented;
- no upstream source or Compose file was modified.

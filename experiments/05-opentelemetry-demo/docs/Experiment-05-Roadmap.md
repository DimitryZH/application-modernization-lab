# Experiment 05 - Full OpenTelemetry Demo / Astronomy Shop Migration

## Objective

Validate whether Codex can migrate a full observability-enabled, message-broker-based, multi-service Docker Compose application to .NET Aspire.

Target application:

- OpenTelemetry Demo (Astronomy Shop)
- Full Docker Compose deployment
- Kafka
- OpenTelemetry Collector
- Grafana
- Jaeger
- Prometheus
- Distributed microservices

---

## Stage A - Source Exploration and Compose Baseline

Status: **PASS with documented baseline limitations** (completed 2026-06-10)

Goals:

- Create Experiment 05 scaffold
- Clone upstream repository
- Record source URL and commit SHA
- Run full Docker Compose deployment on DevBox
- Verify Web Store UI
- Verify Grafana, Jaeger, Load Generator and Feature Flags
- Explore Kafka and OpenTelemetry architecture
- Document topology and findings

Deliverable:

- Baseline validation report
- Architecture documentation
- Kafka and observability documentation

Result:

- The official full four-layer Compose deployment was explored and validated on the existing DevBox.
- Required user interfaces and the traces, metrics, and logs paths were validated.
- Upstream startup-readiness and runtime limitations were recorded for use as migration comparison criteria.

---

## Stage B - Migration Strategy

Status: **PASS** (completed 2026-06-11)

Goals:

- Analyze Docker Compose topology
- Define Aspire resource mapping
- Define migration approach
- Identify risks and validation criteria

Deliverable:

- Full migration strategy
- 29-service Aspire resource mapping
- Stage C implementation plan
- Stage B migration strategy report

Result:

- Defined a full-application migration strategy for all 29 resolved Compose
  services.
- Selected pinned prebuilt images and explicit Aspire topology as the primary
  preservation-first approach.
- Defined Kafka, Collector, observability, startup, validation, and baseline
  comparison strategies.
- Defined Stage C implementation order and partial-validation stop points.

---

## Stage C - Full Aspire AppHost Implementation

Status: **PASS** (completed 2026-06-12)

Goals:

- Create Aspire AppHost
- Migrate all services
- Preserve dependencies
- Preserve ports and environment variables
- Preserve Kafka and observability components

Deliverable:

- Full Aspire implementation

### Stage C.1 - Aspire Foundation

Status: **PASS** (completed 2026-06-12)

Result:

- Created the Experiment 05 Aspire solution and empty AppHost foundation.
- Declared secret Aspire parameters without tracked values.
- Established configuration-asset and image-pinning strategies.
- Validated the foundation with `dotnet build`.

### Stage C.2 - Infrastructure Layer

Status: **PASS** (completed 2026-06-12)

Result:

- Added digest-pinned `astronomy-db`, `valkey-cart`, `flagd`, and `llm`
  container resources.
- Added tracked PostgreSQL initialization and flagd configuration assets.
- Parameterized PostgreSQL administrator, application, and monitoring
  passwords without tracked secret values.
- Validated the Aspire manifest, PostgreSQL initialization contract, and LLM
  endpoint; recorded the DevBox DCP startup limitation.
- Validated the implementation with `dotnet build` and
  `dotnet build --no-restore`.

### Stage C.3 - Kafka and Accounting Layer

Status: **PASS** (completed 2026-06-12)

Result:

- Added digest-pinned `kafka` and `accounting` container resources.
- Preserved the instrumented single-broker KRaft listener, telemetry, JMX,
  topic auto-creation, and replication-factor contracts.
- Wired accounting to Kafka readiness and the parameterized PostgreSQL
  connection contract.
- Validated Kafka TCP readiness and accounting startup on an isolated Docker
  network without disturbing the Stage A stack.
- Validated the implementation with `dotnet build` and
  `dotnet build --no-restore`.

### Stage C.4 - Observability Backends Layer

Status: **PASS** (completed 2026-06-12)

Result:

- Added digest-pinned `jaeger`, `prometheus`, `opensearch`, and `grafana`
  container resources.
- Added unchanged tracked Jaeger, Prometheus, and Grafana configuration assets.
- Preserved backend endpoints, health checks, OpenSearch runtime constraints,
  Prometheus OTLP receiver flags, and Grafana provisioning.
- Validated all four direct health endpoints on an isolated Docker network
  without disturbing the Stage A stack.
- Validated the implementation with `dotnet build` and
  `dotnet build --no-restore`.

### Stage C.5 - Application and Telemetry Layer

Status: **PASS** (completed 2026-06-12)

Result:

- Added the OpenTelemetry Collector and all remaining application, support,
  and orchestration resources.
- Preserved the Collector's four-layer configuration order, backend
  integrations, receivers, exporters, root runtime, and local host mounts.
- Completed the 29-container Aspire topology and 29-entry image lock.
- Preserved secret-backed application and Collector environment values.
- Validated the complete static topology through Aspire manifest publication.
- Validated the implementation with `dotnet build` and
  `dotnet build --no-restore`.

---

## Stage D - Aspire Runtime Validation

Status: **PASS with documented baseline limitations** (completed 2026-06-13)

Goals:

- Build Aspire solution
- Start AppHost
- Validate services
- Validate endpoints
- Execute smoke tests

Deliverable:

- Runtime validation report

Result:

- Started the complete Aspire AppHost and reached a stable 29-running-resource
  state with no unhealthy or exited containers.
- Validated all required frontend-proxy and Prometheus endpoints with HTTP 200.
- Validated storefront browse, product, cart, checkout recovery, Kafka order,
  accounting consumption, and Collector signal-processing paths.
- Fixed frontend HTTP health modeling and preserved restart behavior for
  checkout and fraud-detection.
- Reproduced and documented the known fraud-detection, startup timing, Load
  Generator, and Collector baseline limitations.

---

## Stage E - Observability Validation

Goals:

- Validate traces
- Validate metrics
- Validate logs
- Validate Collector pipelines
- Validate Grafana and Jaeger integration

Deliverable:

- Observability validation report

---

## Stage F - Functional and Operational Equivalence Review

Goals:

- Compare Compose and Aspire deployments
- Identify differences
- Classify limitations and failures

Deliverable:

- Equivalence review

---

## Stage G - Final Assessment

Goals:

- Calculate final score
- Summarize findings
- Evaluate migration success
- Determine production-readiness of the approach

Deliverable:

- Final assessment report

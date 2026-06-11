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

Goals:

- Create Aspire AppHost
- Migrate all services
- Preserve dependencies
- Preserve ports and environment variables
- Preserve Kafka and observability components

Deliverable:

- Full Aspire implementation

---

## Stage D - Aspire Runtime Validation

Goals:

- Build Aspire solution
- Start AppHost
- Validate services
- Validate endpoints
- Execute smoke tests

Deliverable:

- Runtime validation report

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

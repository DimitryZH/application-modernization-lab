# Compose-to-Aspire Migration Research

This repository contains Docker Compose → .NET Aspire migration experiments, validation evidence, and migration patterns collected across progressively more complex application architectures.

## Research Goal

Evaluate whether AI-assisted engineering workflows can reliably migrate increasingly complex Docker Compose applications to .NET Aspire while preserving:

* application functionality;
* service dependencies;
* messaging systems;
* observability pipelines;
* operational behavior.

## Experiment Results

| Experiment    | Scope                                                            | Result        |
| ------------- | ---------------------------------------------------------------- | ------------- |
| Experiment 01 | Controlled demo                                                  | PASS          |
| Experiment 02 | Browser-constrained migration                                    | 6/10          |
| Experiment 03 | Docker Example Voting App migration                              | 8/10          |
| Experiment 04 | Google Cloud DevBox remote execution validation                  | PASS (95/100) |
| Experiment 05 | Full OpenTelemetry Demo / Astronomy Shop migration (29 services) | PASS (94/100) |

## Highlight: Experiment 05

Experiment 05 successfully migrated the complete OpenTelemetry Demo (Astronomy Shop) application from Docker Compose to .NET Aspire.

### Migration Scope

* 29 services migrated
* 29/29 services represented in Aspire
* Kafka messaging preserved
* OpenTelemetry Collector preserved
* Jaeger preserved
* Prometheus preserved
* Grafana preserved
* OpenSearch preserved
* Full application topology preserved

### Validation Results

* Full Aspire runtime validation completed
* Functional storefront workflow validated
* Checkout workflow validated
* Kafka producer and consumer paths validated
* Distributed tracing validated
* Metrics pipeline validated
* Logging pipeline validated
* Observability stack validated

### Final Result

```text
29/29 services migrated
No unresolved MIGRATION_FAILURE
Final Score: 94/100
```

## Key Findings

### AI-Assisted Migration Works

The experiments demonstrate that AI-assisted workflows can successfully migrate complex multi-service applications from Docker Compose to .NET Aspire.

### Observability Can Be Preserved

Distributed tracing, metrics, logs, dashboards, and OpenTelemetry Collector pipelines can be migrated while maintaining operational visibility.

### Messaging Can Be Preserved

Kafka-based producer/consumer workflows can be represented in Aspire while preserving application behavior.

### Remote Execution Improves Reliability

Remote Linux DevBox execution provides a more reliable migration environment than browser-constrained execution environments.

## Repository Structure

```text
.
|-- AGENTS.md
|-- experiments/
|   |-- 01-controlled-demo/
|   |-- 02-open-source-voting-app/
|   |-- 03-codex-desktop-voting-app/
|   |-- 04-google-cloud-devbox/
|   `-- 05-opentelemetry-demo/
|-- LICENSE
`-- README.md
```

## Recommended Reading

1. Experiment 05 Final Assessment
2. Experiment 05 Equivalence Review
3. Experiment 04 DevBox Validation
4. Experiment 03 Voting App Migration

## Conclusions

The repository demonstrates a progression from small controlled migrations to a full observability-enabled, message-broker-based, 29-service application migration.

The final experiment shows that Docker Compose to .NET Aspire migration can preserve functional behavior, messaging workflows, and observability pipelines while maintaining a reproducible and auditable migration process.

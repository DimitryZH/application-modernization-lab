# Experiment 05: OpenTelemetry Demo

## Purpose

Experiment 05 evaluates a future Docker Compose to .NET Aspire migration of the full OpenTelemetry Demo, also known as Astronomy Shop.

Stage A establishes the source baseline and explores the existing architecture. It does not implement an Aspire migration.

## Scope

The target includes:

- distributed application services;
- Kafka-based messaging;
- OpenTelemetry Collector pipelines;
- Grafana;
- Jaeger;
- Prometheus;
- load generation;
- feature flags.

## Layout

- `source/`: pinned upstream source metadata and clone instructions.
- `docs/`: roadmap and architecture exploration documents.
- `reports/`: validation and stage reports.
- `scripts/`: experiment-specific helper scripts, when required.

## Stage A

Stage A uses a pinned upstream clone on the Google Cloud DevBox to inspect and validate the full Docker Compose deployment without modifying upstream source code.

See:

- [Experiment roadmap](docs/Experiment-05-Roadmap.md)
- [Source project overview](docs/source-project-overview.md)
- [Compose topology](docs/compose-topology.md)
- [Observability architecture](docs/observability-architecture.md)
- [Kafka and messaging](docs/kafka-and-messaging.md)
- [Failure scenarios and migration risks](docs/failure-scenarios.md)
- [Exploration notes](docs/exploration-notes.md)
- [Stage A report](reports/stage-a-source-exploration-and-compose-baseline.md)

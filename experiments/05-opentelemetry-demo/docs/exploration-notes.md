# Stage A Exploration Notes

## Method

Stage A used the existing private DevBox and the official upstream source at the pinned commit. No cloud resources were created, no public access was added, no upstream source was modified, and no Aspire migration was started.

The source clone and raw runtime logs remain outside the tracked experiment directory. This keeps external source, local environment files, and environment-specific runtime evidence out of the repository.

## Deployment Sequence

1. Clone and pin the official upstream repository.
2. Inspect the four Compose layers and resolved topology.
3. Run the official `make start` target.
4. Observe OpenSearch readiness timeout.
5. Wait for OpenSearch and Kafka health checks to pass.
6. Continue the same full Compose deployment without forced recreation.
7. Validate containers, user interfaces, signals, Kafka behavior, and runtime limitations.

## Validation Summary

- Resolved services: 29
- Running containers: 29
- Containers with Docker health state `unhealthy`: 0
- Exited containers: 0
- Required interface HTTP results: all `200`
- Jaeger service count observed: 17
- Grafana health: database `ok`
- Prometheus: metrics present through OTLP ingestion
- OpenSearch: logs index present
- Load Generator: running, with baseline HTTP failures
- Kafka: healthy, with accounting consumer activity
- Fraud detection: running under restart policy but unstable

## Access Notes

Normal external SSH was not available during Stage A. DevBox access used Identity-Aware Proxy tunneling. Validation endpoints were accessed only from the DevBox localhost.

A diagnostic SSH troubleshooting attempt requested activation of an additional Google Cloud diagnostic API before failing. That diagnostic API is not required by the experiment and no firewall or VM configuration changes were made.

## Stage Result

Stage A is a pass with documented baseline limitations. It successfully established the source, architecture, deployment, and observability baseline required for Stage B. The baseline itself is not fully error-free, and later comparisons must preserve that distinction.

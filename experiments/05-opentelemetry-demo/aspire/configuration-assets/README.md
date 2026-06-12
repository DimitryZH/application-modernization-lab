# Configuration Assets

This directory will contain tracked copies of configuration files required by
the Experiment 05 Aspire deployment.

Assets will be grouped by owning resource:

```text
configuration-assets/
  flagd/
  frontend-proxy/
  grafana/
  jaeger/
  otel-collector/
  postgres/
  product-catalog/
  prometheus/
```

Each copy must be recorded in `docs/configuration-assets-strategy.md` with its
upstream path, upstream commit, purpose, and any intentional local changes.

Stage C.2 adds:

- the unchanged flagd definition file;
- the PostgreSQL initialization SQL with password literals replaced by psql
  variables;
- an Aspire-specific PostgreSQL initialization adapter that supplies secret
  parameter values to the SQL file.

Stage C.4 adds unchanged upstream configuration for:

- Jaeger;
- Prometheus;
- Grafana and its complete provisioning tree.

Copied configuration content remains unchanged. Directories use mode `0755`
and files use mode `0644` so the non-root backend images can read the tracked
bind mounts on the DevBox.

Stage C.5 adds unchanged upstream configuration for:

- the four ordered OpenTelemetry Collector configuration layers;
- the product-catalog OpenTelemetry SDK configuration.

The flagd directory is mounted writable by both `flagd` and `flagd-ui` to
preserve the upstream shared feature-flag editing contract.

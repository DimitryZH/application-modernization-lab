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

Stage C.1 intentionally adds no upstream configuration files. Each future copy
must be recorded in `docs/configuration-assets-strategy.md` with its upstream
path, upstream commit, purpose, and any intentional local changes.

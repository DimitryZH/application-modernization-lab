# Configuration Assets and Parameter Strategy

## Purpose

Define how Experiment 05 will manage configuration files and sensitive values
while implementing the full Aspire AppHost.

## Asset Location

Tracked configuration copies will live under:

```text
experiments/05-opentelemetry-demo/aspire/configuration-assets/
```

Assets will be grouped by owning resource. The initial planned groups are
`flagd`, `frontend-proxy`, `grafana`, `jaeger`, `otel-collector`, `postgres`,
`product-catalog`, and `prometheus`.

The pinned upstream source remains an inspection source and must not be
modified. AppHost resources will mount only the tracked copies from
`configuration-assets/`, so the Aspire implementation remains reviewable and
does not depend on an untracked external clone at runtime.

## Upstream Tracking

Every copied asset must be recorded in this document when introduced. Its
record must include:

- the destination path under `configuration-assets/`;
- the original upstream path;
- upstream repository and commit
  `b5320139de38b789654a9653d5c4fda441b5cb8f`;
- the owning Aspire resource;
- whether the copy is unchanged or intentionally adapted;
- a short explanation and validation evidence for each adaptation.

Future stages should compare copied files against the pinned upstream commit
before runtime validation. Unreviewed generated files and secrets must not be
stored in `configuration-assets/`.

## Mount Strategy

- Mount tracked files and read-only directories with explicit host and
  container paths in AppHost code.
- Use writable mounts only where the source behavior requires mutation, such
  as the shared flagd data file. Document each writable exception.
- Keep mount declarations next to the owning resource.
- Preserve the Collector configuration merge order: base, full,
  observability, then extras.
- Keep local-only host integrations, including the Collector Docker socket and
  host filesystem mounts, explicit and documented.
- Do not use absolute DevBox paths in tracked AppHost code.
- Keep read-only configuration directories executable and files readable by
  non-root container users. Unless a stricter resource-specific mode is
  required, copied directories use `0755` and copied files use `0644`.

## Parameter Strategy

The AppHost declares these Aspire parameters as secret values:

| Aspire parameter | Future use |
| --- | --- |
| `postgres-password` | PostgreSQL administrator password |
| `astronomy-user-password` | Shared upstream `astronomy_user` role password |
| `monitoring-user-password` | Upstream `monitoring_user` role password |
| `openai-api-key` | `OPENAI_API_KEY` for product reviews |
| `flagd-ui-secret` | flagd UI `SECRET_KEY_BASE` |

No parameter has a tracked default value. Developers and validation automation
must supply values through Aspire user secrets or an approved external secret
provider. No `.env` file will be created or copied.

Future sensitive values must be added as `secret: true` Aspire parameters with
descriptive kebab-case names. Non-sensitive settings belong in AppHost
configuration or explicit resource environment declarations. Secret values
must never appear in source, reports, logs, configuration assets, or image
metadata.

## Tracked Asset Inventory

| Destination | Upstream path | Owner | State | Notes |
| --- | --- | --- | --- | --- |
| `configuration-assets/flagd/demo.flagd.json` | `src/flagd/demo.flagd.json` | `flagd`, `flagd-ui` | Unchanged | Shared through writable directory mounts to preserve flagd UI mutation behavior. |
| `configuration-assets/postgres/init.sql` | `src/postgresql/init.sql` | `astronomy-db` | Adapted | Only the two hardcoded role passwords were replaced with psql variables. Schemas, tables, grants, and seed data remain unchanged. |
| `configuration-assets/postgres/01-init.sh` | None | `astronomy-db` | Aspire-specific adapter | Passes secret environment values to the adapted SQL through psql variables without storing them in tracked files. |
| `configuration-assets/jaeger/config.yml` | `src/jaeger/config.yml` | `jaeger` | Unchanged content | Mounted read-only at `/etc/jaeger/config.yml`; tracked as mode `0644` for the non-root image. |
| `configuration-assets/prometheus/prometheus-config.yaml` | `src/prometheus/prometheus-config.yaml` | `prometheus` | Unchanged content | Mounted read-only at `/etc/prometheus/prometheus-config.yaml`; tracked as mode `0644` for the non-root image. |
| `configuration-assets/grafana/grafana.ini` | `src/grafana/grafana.ini` | `grafana` | Unchanged content | Mounted read-only at `/etc/grafana/grafana.ini`; tracked as mode `0644` for the non-root image. |
| `configuration-assets/grafana/provisioning/` | `src/grafana/provisioning/` | `grafana` | Unchanged content | Complete provisioning tree mounted read-only; directories use `0755` and files use `0644` for the non-root image. |
| `configuration-assets/otel-collector/otelcol-config.yml` | `src/otel-collector/otelcol-config.yml` | `otel-collector` | Unchanged | First Collector configuration layer. |
| `configuration-assets/otel-collector/otelcol-config-full.yml` | `src/otel-collector/otelcol-config-full.yml` | `otel-collector` | Unchanged | Second Collector configuration layer with full-deployment receivers. |
| `configuration-assets/otel-collector/otelcol-config-observability.yml` | `src/otel-collector/otelcol-config-observability.yml` | `otel-collector` | Unchanged | Third Collector configuration layer with backend exporters. |
| `configuration-assets/otel-collector/otelcol-config-extras.yml` | `src/otel-collector/otelcol-config-extras.yml` | `otel-collector` | Unchanged | Final Collector customization layer. |
| `configuration-assets/product-catalog/otel-config.yml` | `otel-config.yml` | `product-catalog` | Unchanged | Mounted read-only at `/otel-config.yml`. |

All upstream copies are from commit
`b5320139de38b789654a9653d5c4fda441b5cb8f`.

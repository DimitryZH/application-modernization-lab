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

## Parameter Strategy

Stage C.1 declares these Aspire parameters as secret values:

| Aspire parameter | Future use |
| --- | --- |
| `postgres-password` | PostgreSQL administrator password |
| `accounting-db-password` | Accounting database role password |
| `product-catalog-db-password` | Product catalog database role password |
| `product-reviews-db-password` | Product reviews database role password |
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

## Stage C.1 State

The tracked asset directory currently contains only its README. Configuration
copies and mounts will be added by the later Stage C implementation layers that
own them.

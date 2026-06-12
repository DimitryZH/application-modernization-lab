# Stage C.4: Observability Backends Layer Report

## Result

**PASS**

Stage C.4 added the four observability backend resources to the Experiment 05
Aspire AppHost. Build, static topology, configuration asset comparison, and
isolated targeted runtime validation passed. The Stage A Compose stack remained
running and was not modified.

## Resources Added

| Resource | Representation | Image |
| --- | --- | --- |
| `prometheus` | Explicit container | `quay.io/prometheus/prometheus:v3.9.1`, pinned by Stage A digest |
| `jaeger` | Explicit container | `quay.io/jaegertracing/jaeger:2.14.1`, pinned by Stage A digest |
| `opensearch` | Explicit container | `ghcr.io/open-telemetry/demo:latest-opensearch`, pinned by Stage A digest |
| `grafana` | Explicit container | `grafana/grafana:13.0.1`, pinned by Stage A digest |

No Collector, application service, frontend, proxy, or load generator was
added.

## Backend Contracts

Prometheus preserves the stable host port `9090`, seven-day retention, OTLP
receiver, exemplar storage, lifecycle endpoint, configuration mount, and
`/-/healthy` health check.

Jaeger preserves the upstream configuration, UI endpoint, OTLP gRPC endpoint,
Collector and Prometheus address intent, memory trace limit, and the
configuration-defined `/status` health endpoint.

OpenSearch preserves the instrumented demo image, single-node cluster,
security-disabled behavior, `400m` heap settings, unlimited memlock, `65536`
nofile limit, cluster health command, and HTTP health endpoint.

Grafana preserves the OpenSearch datasource plugin installation, upstream
configuration, complete provisioning tree, backend references, and
`/api/health` health check.

## Image Lock

`aspire/image-lock.json` now contains ten entries. Stage C.4 adds:

- `jaeger` at digest
  `sha256:39317a963b8006d0664bb1fc4c0bbdbf7cb9dcd20b9b57c23b6ebc09ab4f3cd6`;
- `prometheus` at digest
  `sha256:1f0f50f06acaceb0f5670d2c8a658a599affe7b0d8e78b898c1035653849a702`;
- `opensearch` at digest
  `sha256:b56ba5f10cce29854dbfcdb4fbe561e733681dd542e5eaa55ff67b335e532858`;
- `grafana` at digest
  `sha256:0f86bada30d65ef9d0183b90c1e2682ac92d53d95da8bed322b984ea78a4a73a`.

The digests and image IDs were captured from the running Stage A containers.
No credentials or secret values were added to the image inventory.

## Configuration Assets

Stage C.4 copied these assets from pinned upstream commit
`b5320139de38b789654a9653d5c4fda441b5cb8f`:

- `src/jaeger/config.yml`;
- `src/prometheus/prometheus-config.yaml`;
- `src/grafana/grafana.ini`;
- the complete `src/grafana/provisioning/` tree.

Content comparison against the pinned upstream checkout passed. The first
targeted start exposed restrictive DevBox copy modes that prevented non-root
backend images from reading their bind mounts. Content remained unchanged,
while tracked directories were set to `0755` and files to `0644`. The second
targeted start passed.

## Build Validation

Commands executed from `experiments/05-opentelemetry-demo/aspire/`:

```bash
dotnet build
dotnet build --no-restore
```

Both builds succeeded with zero errors using .NET SDK `10.0.109` and Aspire
`13.3.5`. The existing `NU1903` warning remains for the transitive
`MessagePack 2.5.192` dependency.

## Static Topology Validation

Aspire manifest publication succeeded and confirmed:

- ten container resources through Stage C.4;
- immutable digest references for all four observability backends;
- backend endpoints, environment variables, arguments, mounts, and references;
- Prometheus stable host port `9090`;
- read-only configuration asset mounts;
- no Collector or application resources beyond the completed prior stages.

As in prior stages, the manifest publisher logged a sandbox-only auxiliary
backchannel socket permission error after writing the manifest.

## Targeted Runtime Validation

Targeted validation used temporary containers on an isolated
`exp05-c4-validation` Docker network. It did not connect to or modify the
Stage A Compose network.

Validation confirmed:

- Prometheus returned `Prometheus Server is Healthy.` from `/-/healthy`;
- Jaeger returned `healthy: true` from `/status`, and its UI API responded;
- OpenSearch reached Docker health `healthy` and returned a green,
  single-node cluster health result;
- Grafana returned `database: ok` and version `13.0.1` from `/api/health`;
- Grafana installed `grafana-opensearch-datasource` version `2.33.1`;
- Grafana provisioned the Prometheus, Jaeger, and OpenSearch datasources and
  upstream dashboards.

No telemetry signal data was required at this stage. All temporary Stage C.4
validation containers and the isolated network were removed after validation.

## Known Issues and Remaining Risks

1. Jaeger emits expected metric export errors while the Collector is absent.
2. Signal ingestion and backend data equivalence remain deferred until the
   Collector and application services are present.
3. Prometheus intentionally binds stable host port `9090`; a full Aspire start
   cannot run beside the Stage A Prometheus without an approved staging step.
4. OpenSearch readiness can be slow and later validation must avoid unnecessary
   recreation.
5. Grafana logged a non-blocking permission warning while attempting to update
   a bundled Elasticsearch plugin. Grafana remained healthy and the required
   OpenSearch plugin and provisioning passed.
6. Full AppHost runtime validation remains deferred; the prior DevBox DCP
   API-server timeout must be reassessed in later stages.
7. The existing transitive `MessagePack 2.5.192` `NU1903` warning remains.
8. Stage C.5 must preserve Collector configuration merge order and wait for
   Jaeger start and OpenSearch health.

## Scope and Hygiene Confirmation

- No Collector, application service, frontend, proxy, or load generator
  resource was added.
- No upstream source or Compose file was modified.
- The pinned upstream checkout remained clean.
- No secrets, tokens, external IPs, SSH fingerprints, or personal identity
  values were added.
- The hygiene scan matched only commented upstream Grafana sample/default
  values and existing Aspire secret parameter declarations; no active
  credential value was introduced.

## Suggested Commit Message

```text
feat(experiment-05): add Aspire observability backends
```

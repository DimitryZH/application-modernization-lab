# Stage C.5: Application and Telemetry Layer Report

## Result

**PASS**

Stage C.5 completes the Experiment 05 Aspire AppHost implementation. The
AppHost now represents all 29 services from the resolved four-layer
OpenTelemetry Demo deployment. Full runtime validation remains deferred to
Stage D.

## Resources Added

Telemetry:

- `otel-collector`

Core and support services:

- `product-catalog`
- `product-reviews`
- `cart`
- `recommendation`
- `payment`
- `shipping`
- `quote`
- `currency`
- `email`
- `image-provider`
- `ad`
- `telemetry-docs`
- `flagd-ui`

Orchestration services:

- `checkout`
- `frontend`
- `frontend-proxy`
- `load-generator`
- `fraud-detection`

## Complete Topology

Aspire manifest publication confirmed exactly 29 container resources, matching
the 29 resolved Compose services with no omissions. The manifest also
confirmed immutable digest references for every container.

The AppHost preserves the stable host contracts:

- frontend-proxy storefront port `8080`;
- frontend-proxy admin port `10000`;
- Prometheus port `9090`.

## Collector Status

The Collector uses the exact Stage A image digest and preserves:

- OTLP gRPC port `4317` and OTLP HTTP port `4318`;
- ordered configuration merge: base, full, observability, extras;
- the profiles feature gate;
- Jaeger, Prometheus, and OpenSearch backend intent;
- Kafka, PostgreSQL, Valkey, NGINX, ad, Docker, host, and HTTP receiver
  environment contracts;
- secret-backed PostgreSQL monitoring password;
- root runtime requirement;
- read-only host filesystem and Docker socket mounts;
- startup dependencies on Jaeger and healthy OpenSearch.

The Collector configuration assets are unchanged copies from pinned upstream
commit `b5320139de38b789654a9653d5c4fda441b5cb8f`.

## Configuration Assets

Stage C.5 adds unchanged tracked copies of:

- `src/otel-collector/otelcol-config.yml`;
- `src/otel-collector/otelcol-config-full.yml`;
- `src/otel-collector/otelcol-config-observability.yml`;
- `src/otel-collector/otelcol-config-extras.yml`;
- root `otel-config.yml` for product-catalog.

Content comparison against the pinned upstream checkout passed. The flagd
asset directory is now shared through writable mounts for `flagd` and
`flagd-ui`, preserving the upstream feature-flag editing contract.

## Image Lock

`aspire/image-lock.json` now contains all 29 resolved deployment images.
Stage C.5 added 19 entries captured from the running Stage A containers. No
floating image tag remains unpinned in AppHost.

## Build and Static Validation

Commands executed from `experiments/05-opentelemetry-demo/aspire/`:

```bash
dotnet build
dotnet build --no-restore
```

Both builds succeeded with zero errors using .NET SDK `10.0.109` and Aspire
`13.3.5`. The existing `NU1903` warning remains for transitive dependency
`MessagePack 2.5.192`.

Aspire manifest publication succeeded and confirmed:

- exactly 29 container resources;
- all Collector arguments and read-only mounts;
- secret expressions remain parameter references;
- all stable host ports;
- complete application and orchestration resource coverage.

The manifest publisher logged the previously documented sandbox-only
auxiliary backchannel socket permission error after writing the manifest.

## Validation Scope

No full-stack startup or functional smoke test was performed. Those checks are
explicitly reserved for Stage D. Stage C.5 targeted validation was limited to
build, manifest, image inventory, configuration comparison, and repository
hygiene.

## Remaining Blockers and Risks Before Stage D

1. Full AppHost startup must provide all five secret parameters.
2. The Stage A stack currently occupies stable ports `8080`, `10000`, and
   `9090`; Stage D requires an approved staging transition before Aspire
   startup.
3. Kafka and OpenSearch need extended readiness windows.
4. Collector host filesystem and Docker socket mounts are local-validation
   integrations and must remain read-only.
5. The known fraud-detection flagd resolver behavior may reproduce.
6. The existing DevBox DCP API-server timeout must be reassessed during Stage
   D.
7. The existing `MessagePack 2.5.192` `NU1903` warning remains.

## Scope and Hygiene Confirmation

- All 29 resolved Compose services are represented.
- No upstream source or Compose file was modified.
- No tracked secret values were added.
- Full runtime validation was not performed.

## Suggested Commit Message

```text
feat(experiment-05): complete Aspire application topology
```

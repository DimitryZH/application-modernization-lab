# Online Shop

Canonical application source and portable Kubernetes configuration for Online Shop, based on [Google microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) **v0.10.4**, commit `474d0f2eb73d97525234995a40d7781b7923a07d`. This workload is separate from the historical experiments. See [UPSTREAM.md](UPSTREAM.md) for the import boundary and modifications, and [VALIDATION.md](VALIDATION.md) for checks and limitations.

## Structure

```text
online-shop/
  src/                     # 10 application services and the load generator
  protos/                  # shared definitions, including gRPC health protocol
  kubernetes/online-shop.yaml
  images.lock.json          # source/build contexts and existing runtime artifacts
  LICENSE                  # upstream Apache-2.0 license
  UPSTREAM.md
  VALIDATION.md
```

The eleven source directories are `adservice`, `cartservice`, `checkoutservice`, `currencyservice`, `emailservice`, `frontend`, `loadgenerator`, `paymentservice`, `productcatalogservice`, `recommendationservice`, and `shippingservice`. Redis is an external runtime dependency: it has an image mapping and Kubernetes resources, but no local source or Dockerfile.

## Sources, images and future builds

These are four distinct records:

1. The pinned upstream snapshot supplies the imported source, Dockerfiles, generated protocol bindings and build inputs.
2. This folder is a local adaptation of that snapshot, with Online Shop text branding and a portable application configuration.
3. The existing Docker Hub images are copies of upstream artifacts, obtained by pulling, renaming and pushing. They were **not built from this folder** and do **not contain the local branding changes**. Their source/build records remain unknown; the source paths in this folder are future build inputs, not historical image provenance.
4. Future CI Build Platform integration must build the adapted sources and record actual source revisions, producing runs and new image digests. No CI integration is implemented here. New branding reaches runtime only after that future rebuild and image-reference update.

[images.lock.json](images.lock.json) records all 12 component IDs, roles, internal workload/Service names, SRE aliases, build contexts, Dockerfiles, discovery tags, repositories, platform-specific manifest digests and unchanged legacy traceability findings. Redis source/build fields are null. Application/helper images have discovery tag `v0.10.4`; Redis has discovery tag `7-alpine`. Kubernetes uses only `docker.io/dmitryzhuravlev/online-shop-<component>@sha256:...` references; tags do not select artifacts.

Mappings and digests come from Container Platform [PR #4](https://github.com/DimitryZH/container-platform/pull/4), pinned at **`f9105f58aefd949a6729eea4ab31f7223dc05206`**:

- [Inventory](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/inventories/online-shop-sre-dev-v1.json)
- [Release candidate](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/releases/baseline-2026-10-18.json)
- [Registry observations](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/releases/baseline-2026-10-18.observations.json)
- [Baseline findings](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/docs/baseline.md)

The baseline observed exact upstream artifact digest matches for all **11 application/helper images**. This establishes artifact equality at observation time, not an authenticated producing source revision or build run. Redis metadata identified 7.4.8, but its exact publisher lineage remains unresolved. This import closes none of those historical provenance gaps and grants no release approval.

## Build inputs

The versioned [source-to-build contract and consumer interface](BUILDING.md)
cover all eleven builds, deterministic selected-revision plans, shared/generated
inputs and clean-source evidence. The [portable runtime handoff](RUNTIME.md)
documents application settings and runtime-specific telemetry behavior.

Each component's build context and Dockerfile are explicit in the mapping. Contexts are `src/<component>`, except cartservice, whose context is `src/cartservice/src`. Preserve this layout: protocol regeneration scripts reference `../../protos` from their service directories.

Included inputs comprise Go modules and `go.sum` files; Node package manifests and package lockfiles; Python requirement pins and generated bindings; the .NET project, local Cart protocol and tests; Java Gradle configuration, wrapper scripts, wrapper JAR and properties; product and currency data; frontend templates, styles, scripts, icons, images and fonts; email templates; Docker ignore files and protocol generation scripts. Existing upstream tests are preserved but were not run.

The upstream snapshot has no universal dependency lock strategy: Python requirements, NuGet and Gradle declarations do not establish fully locked transitive dependency graphs; Dockerfiles can fetch packages and tools from public registries. No missing locks, source attestations or reproducible-build guarantees are invented. Dockerfile base images are future build dependencies and are separate from the 12-image Kubernetes runtime set. Imported service READMEs remain upstream development notes and may contain obsolete commands; the explicit context mapping is authoritative for future build integration.

## Kubernetes profile

[kubernetes/online-shop.yaml](kubernetes/online-shop.yaml) contains 12 Deployments, 11 ClusterIP Services and 11 upstream ServiceAccounts. It preserves upstream selectors, internal DNS names, ports, probes, resource bounds, non-root container security and Redis `emptyDir` storage. It is a portable AML profile with the same component/image membership as `sre-dev-online-shop-v1`, **not a copy of the SRE chart or a claim of configuration/runtime equivalence**. In particular, frontend is a Deployment here; the SRE frontend Rollout belongs to SRE infrastructure.

Adaptations:

- Pin all 12 images to baseline digests and constrain scheduling to `linux/amd64`.
- Remove the upstream load-generator BusyBox init container, which is absent from the selected SRE baseline. There is no replacement image or startup gate; initial load-generator requests may fail until frontend becomes ready.
- Remove `frontend-external` LoadBalancer to avoid automatic external exposure and cloud cost. Frontend remains reachable internally through `frontend:80`.
- Remove Istio-specific probe annotations, disable service-account token automounting, set frontend platform to `local`, and explicitly disable its optional assistant while setting its required address to the disabled loopback sentinel `127.0.0.1:1`. The upstream frontend requires this address even with the feature disabled. Its flag hides the assistant UI; direct assistant API requests remain unsupported and fail against the sentinel. Existing profiler-disabling settings remain.
- Include no SRE infrastructure, failure-injection workload, assistant service, cloud provisioning, environment credentials, ConfigMaps or secret dependencies.

Redis carts are ephemeral and reset with the Pod's storage. Load generation is enabled at the upstream defaults of 10 users and rate 1, so this profile consumes resources and sends synthetic checkout traffic whenever started. Browser assets retain upstream public CDN/font URLs. Optional backend/cloud code remains in imported sources but is not selected by this profile. No deployment was performed; production exposure, persistence, policy, sizing and runtime compatibility require separate review.

## Follow-up after merge

Container Platform must separately update its AML discovery/source-location links in `inventories/online-shop-sre-dev-v1.json` (`sources.aml-baseline`, `sources.aml-manifests`) and `docs/baseline.md` to the merged AML commit and this folder's README/manifests. Preserve historical evidence and existing image traceability; do not relabel the current images as builds from this path. The baseline candidate's historical upstream reference remains historical evidence. No Container Platform files are changed here.

## Explicit telemetry

See [TELEMETRY.md](TELEMETRY.md) for the source instrumentation contract and [local validation](validation/otel/README.md) for isolated source builds and machine-checkable evidence. Historical published-image records above remain unchanged.

## Redis runtime validation

See [REDIS.md](REDIS.md) and [redis.runtime.json](redis.runtime.json) for the
standalone ephemeral-cache contract, shared image mapping, security/storage,
Redis server telemetry, validation commands and downstream ownership.
RDB and AOF are explicitly disabled: Redis process restart also resets carts.

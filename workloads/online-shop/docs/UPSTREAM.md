# Online Shop upstream record

Inline file paths are workload-relative unless stated otherwise. Commands retain their original working directory; commands beginning with `workloads/online-shop/` run from the repository root. Markdown links are document-relative.

- Repository: [Google microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo).
- Selected tag: `v0.10.4`.
- Pinned commit: [`474d0f2eb73d97525234995a40d7781b7923a07d`](https://github.com/GoogleCloudPlatform/microservices-demo/tree/474d0f2eb73d97525234995a40d7781b7923a07d).
- Import date: 2026-10-18.
- Verification: the remote `refs/tags/v0.10.4` resolved directly to this full commit before import; the source archive was retrieved by that commit.
- Imported: the eleven selected `src/` component trees, `protos/` and upstream `LICENSE`. The application manifest is adapted from the pinned `release/kubernetes-manifests.yaml`.
- Excluded: shopping assistant source, upstream CI, Git history, cloud provisioning, Helm/Kustomize/Istio trees, unrelated demos and repository-level development orchestration.

## Local modifications

The frontend header and assistant templates carry modification notices: the document title, navigation logo text and assistant greeting now say Online Shop. The header uses text instead of either upstream logo image. The stylesheet carries a modification notice for the added text-logo rule. SVG accessible title text now says Online Shop and carries modification notices; vector paths and all binary artwork remain unchanged. Some unreferenced upstream logo assets therefore remain available in the source tree.

Imported text files also have trailing whitespace/blank lines normalized for repository diff checks. This has no intended behavioral effect. The local `.gitattributes` keeps text in LF form and marks image/JAR files as binary. Executable scripts retain executable Git modes.

The optional Spanner backend's default instance name in `src/cartservice/src/cartstore/SpannerCartStore.cs` is adapted to `online-shop`, with a modification notice in the source file. Explicit Spanner configuration still overrides this default. The selected Redis profile is unaffected; existing image mappings and digests are unchanged, and the source adaptation reaches images only after a future rebuild.

Kubernetes modifications, exact image origins, future build boundaries and follow-ups are documented in [the runtime profile](RUNTIME.md#kubernetes-profile) and the image-origin and follow-up sections below. No service protocol, module name, import, dependency version or build recipe is intentionally changed. Shared definitions and generated protocol code remain upstream-compatible identifiers, without a claim of tested compatibility.

## Retained upstream naming and attribution

- `hipstershop` / `Hipstershop` remains in protocol packages, generated bindings, Go module/import paths, C# namespaces, Java packages, Gradle output names and the matching Docker entrypoint. Renaming these would require coordinated code/protocol changes unrelated to user-facing branding.
- `CYMBAL_BRANDING`, `is_cymbal_brand` and related Go identifiers remain for the upstream favicon switch. `cymbal-*` classes/selectors remain in templates/styles; renaming them would require synchronized styling changes without user-facing benefit.
- `Hipster_*`, `Cymbal_*` and `favicon-cymbal.ico` remain as imported asset filenames/references. Path-based logos retain upstream artwork; ordinary SVG title metadata is adapted to Online Shop. The main navigation no longer uses the upstream logo images. Binary icons are unchanged.
- Public upstream links, copyright/license text, module URLs and service README build-output names remain accurate attribution or internal references. Their occurrences are not local product names.

No remaining ordinary page-title or greeting text uses the former product branding. Historical experiments and their paths are untouched.

## License

The imported snapshot is distributed under the upstream [Apache License 2.0](../LICENSE). Original copyright headers, generated-code notices, Gradle wrapper license header and the frontend Google LLC attribution/source link are retained. No additional `LICENSE*` or `NOTICE*` files exist inside the selected upstream component trees or shared protocol tree. This is not a dependency-license audit; dependency packages and future build artifacts may carry additional obligations. The repository root license does not replace the imported upstream license.

## Issue #21 instrumentation changes

Local source now owns manual OpenTelemetry initialization, transport/business spans, metrics and safe correlated stdout records. Existing instrumentor registration is replaced, checkout and optional HTTP context propagation are corrected, and dependency/build compatibility changes are documented in [TELEMETRY.md](TELEMETRY.md). Protocol and package identifiers remain unchanged. Existing image mappings are not relabeled as builds of this implementation.


## Sources, images and future builds

These are four distinct records:

1. The pinned upstream snapshot supplies the imported source, Dockerfiles, generated protocol bindings and build inputs.
2. This folder is a local adaptation of that snapshot, with Online Shop text branding and a portable application configuration.
3. The existing Docker Hub images are copies of upstream artifacts, obtained by pulling, renaming and pushing. They were **not built from this folder** and do **not contain the local branding changes**. Their source/build records remain unknown; the source paths in this folder are future build inputs, not historical image provenance.
4. Future CI Build Platform integration must build the adapted sources and record actual source revisions, producing runs and new image digests. No CI integration is implemented here. New branding reaches runtime only after that future rebuild and image-reference update.

[images.lock.json](../images.lock.json) records all 12 component IDs, roles, internal workload/Service names, SRE aliases, build contexts, Dockerfiles, discovery tags, repositories, platform-specific manifest digests and unchanged legacy traceability findings. Redis source/build fields are null. Application/helper images have discovery tag `v0.10.4`; Redis has discovery tag `7-alpine`. Kubernetes uses only `docker.io/dmitryzhuravlev/online-shop-<component>@sha256:...` references; tags do not select artifacts.

Mappings and digests come from Container Platform [PR #4](https://github.com/DimitryZH/container-platform/pull/4), pinned at **`f9105f58aefd949a6729eea4ab31f7223dc05206`**:

- [Inventory](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/inventories/online-shop-sre-dev-v1.json)
- [Release candidate](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/releases/baseline-2026-10-18.json)
- [Registry observations](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/releases/baseline-2026-10-18.observations.json)
- [Baseline findings](https://github.com/DimitryZH/container-platform/blob/f9105f58aefd949a6729eea4ab31f7223dc05206/docs/baseline.md)

The baseline observed exact upstream artifact digest matches for all **11 application/helper images**. This establishes artifact equality at observation time, not an authenticated producing source revision or build run. Redis metadata identified 7.4.8, but its exact publisher lineage remains unresolved. This import closes none of those historical provenance gaps and grants no release approval.


## Follow-up after merge

Container Platform must separately update its AML discovery/source-location links in `inventories/online-shop-sre-dev-v1.json` (`sources.aml-baseline`, `sources.aml-manifests`) and `docs/baseline.md` to the merged AML commit and this folder's README/manifests. Preserve historical evidence and existing image traceability; do not relabel the current images as builds from this path. The baseline candidate's historical upstream reference remains historical evidence. No Container Platform files are changed here.

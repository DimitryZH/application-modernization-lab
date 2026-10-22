# Online Shop upstream record

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

Kubernetes modifications, exact image origins, future build boundaries and follow-ups are documented in [README.md](README.md). No service protocol, module name, import, dependency version or build recipe is intentionally changed. Shared definitions and generated protocol code remain upstream-compatible identifiers, without a claim of tested compatibility.

## Retained upstream naming and attribution

- `hipstershop` / `Hipstershop` remains in protocol packages, generated bindings, Go module/import paths, C# namespaces, Java packages, Gradle output names and the matching Docker entrypoint. Renaming these would require coordinated code/protocol changes unrelated to user-facing branding.
- `CYMBAL_BRANDING`, `is_cymbal_brand` and related Go identifiers remain for the upstream favicon switch. `cymbal-*` classes/selectors remain in templates/styles; renaming them would require synchronized styling changes without user-facing benefit.
- `Hipster_*`, `Cymbal_*` and `favicon-cymbal.ico` remain as imported asset filenames/references. Path-based logos retain upstream artwork; ordinary SVG title metadata is adapted to Online Shop. The main navigation no longer uses the upstream logo images. Binary icons are unchanged.
- Public upstream links, copyright/license text, module URLs and service README build-output names remain accurate attribution or internal references. Their occurrences are not local product names.

No remaining ordinary page-title or greeting text uses the former product branding. Historical experiments and their paths are untouched.

## License

The imported snapshot is distributed under the upstream [Apache License 2.0](LICENSE). Original copyright headers, generated-code notices, Gradle wrapper license header and the frontend Google LLC attribution/source link are retained. No additional `LICENSE*` or `NOTICE*` files exist inside the selected upstream component trees or shared protocol tree. This is not a dependency-license audit; dependency packages and future build artifacts may carry additional obligations. The repository root license does not replace the imported upstream license.

## Issue #21 instrumentation changes

Local source now owns manual OpenTelemetry initialization, transport/business spans, metrics and safe correlated stdout records. Existing instrumentor registration is replaced, checkout and optional HTTP context propagation are corrected, and dependency/build compatibility changes are documented in [TELEMETRY.md](TELEMETRY.md). Protocol and package identifiers remain unchanged. Existing image mappings are not relabeled as builds of this implementation.

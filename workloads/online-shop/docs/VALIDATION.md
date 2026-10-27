# Online Shop static validation

Validation date: 2026-10-18. Checks used the existing local Python standard library and PyYAML, Git and GitHub CLI. No persistent test framework or new toolchain was added.

## Checks

- Verified remote upstream tag `v0.10.4` resolves to `474d0f2eb73d97525234995a40d7781b7923a07d`; downloaded source by full commit.
- Read all four Container Platform baseline files at `f9105f58aefd949a6729eea4ab31f7223dc05206`. Matched all 12 component IDs, roles, repositories, manifest digests, discovery tags, platform and legacy traceability fields against the release, inventory and observation records.
- Compared imported file membership against the selected upstream source trees: all 184 service files and all shared protocol files are included. Checked all 31 local Dockerfile COPY inputs against their explicit build contexts, including the cartservice subdirectory context. Multi-stage COPY sources refer to build outputs, not additional local inputs.
- Checked Gradle wrapper JAR presence, Go module/checksum pairs, Node manifest/lockfile pairs, Python requirement files, local .NET project/Protobuf references and shared protocol regeneration paths. No dependencies were downloaded or resolved.
- Parsed the Kubernetes YAML and checked 34 unique objects: 12 Deployments, 11 Services and 11 ServiceAccounts. Exact membership is ten application services, Redis and load generator. Only the 12 mapped digest references occur in containers; there are no init/ephemeral containers or additional runtime images.
- Checked Deployment selectors against Pod labels, Service selectors and target ports, declared container ports, listener `PORT` values, readiness/liveness probe ports, volume-mount names, service-account references and environment-variable address/Service-port pairs. Checked frontend's unconditional startup environment requirements against the source, with the documented disabled-assistant sentinel exception.
- Confirmed `linux/amd64` node selection, disabled API token automounting, internal-only Services and absence of ConfigMap/Secret references in the profile. Reviewed environment values: no copied GKE/SRE settings, credentials, private endpoints or actual cloud project identifiers were introduced.
- Checked frontend template static-asset paths and parsed SVG XML. Ordinary page-title, navigation and assistant-greeting branding now says Online Shop; SVG accessible title text was adapted while preserving vector paths.
- Compared the imported Apache-2.0 license and retained copyright/license headers with upstream. Binary image/icon/JAR inputs are byte-identical. Selected upstream source/protocol trees contain no additional license/notice files to carry over; dependency licensing was not audited.
- Checked relative Markdown links, executable Git modes, staged file scope, reviewed the import/adaptation diff and ran `git diff --cached --check`.

Retained naming is classified in [UPSTREAM.md](UPSTREAM.md): protocol/module/package names, optional backend defaults, CSS identifiers, imported filenames and artwork, and valid upstream attribution. These are not claims about historical image source or build provenance.

## Limits

These are local structural checks, not full Kubernetes OpenAPI/schema or admission validation. A standalone Kubernetes schema validator and its schema set were not available; no cluster or Kubernetes command was used. Build recipes and local inputs were inspected, but package resolution, regeneration, compilation, image builds, application startup, browser rendering, runtime behavior, compatibility and security scanning were not tested. Existing upstream tests were not run.

No Docker images or layers were pulled, built, retagged or pushed. Registry availability and upstream digest matches are inherited from the pinned Container Platform observation record, not newly observed registry claims. Source imports and manifest structure do not establish reproducible builds, authenticated provenance, production readiness or release approval. All historical source/build gaps remain open.


## Manual telemetry implementation — issue #21

The October 18 record above describes the original import and remains historical. The subsequent implementation built and ran all eleven application images locally, including the original trimmed/self-contained/single-file cartservice release artifact. See [telemetry acceptance results](../validation/otel/RESULTS.md), [reproduction instructions](../validation/otel/README.md), and the [instrumentation contract](TELEMETRY.md) for the new evidence and its limits.

This validation uses an isolated Docker Compose harness for the canonical workload. It does not migrate the workload to Aspire, alter the canonical Kubernetes deployment, publish images, or assert that historical published images contain these source changes.

# Trail Supply source lineage and attribution

## Accepted source

This workload was derived exclusively from tracked Git blobs in
`workloads/online-shop` at AML revision
`67b6cd85ae01c698bbf86904d953d5145b7b5820`. No working-tree artifacts, private
configuration, ignored output, caches or local evidence were copied.
[source-lineage.json](../source-lineage.json) is the machine-readable derivation
record. The original workload and historical experiments are preserved unchanged.

The inherited upstream is Google Cloud Platform
[microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo/tree/474d0f2eb73d97525234995a40d7781b7923a07d),
tag `v0.10.4`, commit `474d0f2eb73d97525234995a40d7781b7923a07d`.
The original import selected eleven component trees, shared protocols and the
upstream LICENSE, excluding the optional shopping assistant source and upstream
cloud/CI orchestration. The foundation preserves all `src/` and `protos/` bytes,
including existing assets, generated bindings and recommendation deadline tests.

## Foundation adaptations

Only workload identity/path metadata, build and validation tooling, documentation
and local Compose orchestration are adapted. `build_plan.py` reads
`workloads/trail-supply` at the selected revision. Build contexts and source paths
remain workload-relative. Test projects, local tags and cache volumes have
Trail Supply-specific prefixes to avoid colliding with Online Shop tooling.

User-facing Online Shop text, the original nine products and advertisements remain
until the later modernization stage. `hipstershop` packages, `online-shop`
service.namespace, service IDs, `ONLINE_SHOP_*`, `CYMBAL_BRANDING`, optional Spanner
defaults, asset filenames and `kubernetes/online-shop.yaml` remain intentional
compatibility or attribution identifiers. They are not stale build paths.

## Historical records, not Trail Supply acceptance

Historical Online Shop results are not duplicated under this workload. The
immutable source records remain available at:

- [Build acceptance and parser review](https://github.com/DimitryZH/application-modernization-lab/tree/67b6cd85ae01c698bbf86904d953d5145b7b5820/workloads/online-shop/validation/build).
- [Telemetry, Redis and recommendation deadline evidence](https://github.com/DimitryZH/application-modernization-lab/tree/67b6cd85ae01c698bbf86904d953d5145b7b5820/workloads/online-shop/validation/otel).
- [Original import and image provenance](https://github.com/DimitryZH/application-modernization-lab/blob/67b6cd85ae01c698bbf86904d953d5145b7b5820/workloads/online-shop/docs/UPSTREAM.md).

The inherited image records and Kubernetes references preserve actual historical
artifact identities and provenance gaps. Application/helper images there were
copies of upstream artifacts, not builds of these instrumented sources. Changing
the workload identity in `images.lock.json` does not turn them into Trail Supply
images. Redis remains the inherited external dependency, including its pending
canonical publication/equality/attestation requirements. No new build, release,
publisher verification or deployment is claimed.

## License

The inherited [Apache License 2.0](../LICENSE), original Google LLC copyright
headers, generated-code notices, Gradle wrapper licensing, SVG modification
notices, image credits and frontend Google/source attribution remain unchanged.
The root repository license does not replace the inherited license. No new visual
assets or third-party application dependencies are introduced in this stage.

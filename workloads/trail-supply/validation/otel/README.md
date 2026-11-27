# Trail Supply telemetry validation

The inherited harness is local to this workload: all application contexts,
protocols, contracts, manifests, probe code and output paths resolve here.
Validation image/cache prefixes are `trail-supply-validation-*`; broad runs use
unique `trail-supply-validation-*` projects, focused Redis runs use
`trail-supply-redis-*`. Service IDs and telemetry namespace stay unchanged.

Historical results are linked in [source lineage](../../docs/UPSTREAM.md); no
copied result file establishes Trail Supply acceptance. New builds and runtime
checks have not yet been executed. The pinned Redis canonical mirror retains its
inherited pending publication/equality/attestation prerequisites.

## Reproduction after runtime approval

Requires a running local Docker Linux/amd64 engine, Compose v2, Python, Git,
registry/package access and capacity for eleven source builds. From repo root:

```powershell
python workloads/trail-supply/validation/otel/run.py
python workloads/trail-supply/validation/otel/run_redis.py
python workloads/trail-supply/validation/otel/unit.py
```

`run.py` builds locally, runs shopping/RPC/failure/concurrency/sampling/exporter/
shutdown checks, records image labels and source fingerprints, and cleans up its
own project. `--only full|disabled|unavailable|refused|redis` narrows scope;
`--skip-build` still rejects stale image labels. Outputs remain under ignored
`output/<project>/`. No runner publishes images or modifies the canonical manifest.

The transparent fault proxy, optional HTTP fixtures, probe and Collector are test
resources. Assertions retain exact counters, duration counts, context parentage,
privacy canaries and correlated safe log checks. Redis infrastructure signals
remain separate from application SDK export. Cleanup destroys only the synthetic
data in that run's project; images, compiler caches and evidence remain local.

`unit.py` uses read-only source mounts and container-local compilation, plus
Trail Supply-specific dependency-cache volumes. Java tests run during its build.
Recommendation tests include both `test_telemetry` and `test_catalog_deadline`.

## Manual visual review

Use [local Compose](../../local/README.md), which has direct service connections,
no fault proxy/Collector, no automatic cleanup and no loadgenerator by default.
Do not browse the acceptance stack during exact telemetry measurement.

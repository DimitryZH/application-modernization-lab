# Redis acceptance evidence — issue #23

AML acceptance **passed** on 2026-10-26. No image publication, downstream
repository modification or deployment occurred. Publisher lineage remains
unresolved; cross-project canonicalization is incomplete.

## Immutable inputs

- Accepted baseline: `1c38ef609ec5f5279a63a7b6466e3ea326fee74c`.
- Final focused tooling: `68e86e39299c4bd499cdba08648f73b0a8fc6ef2`; run `online-shop-23-f3045eac`.
- Cart source revision: `469621fd011626f6ce1e7269034aee525d4fb183`.
- Cart/protocol input SHA-256: `1ce24a826167aebd06dc815b68340300a2636394f358a97318c805c7d32c4d32`
  (sorted tracked paths, NUL separator, then file bytes for each input).
- Broader tooling/source: `a5200cf7cd1718dd287ad8b55f6a87b683c2eb2c`;
  run `online-shop-21-62283fe2`; all eleven source inputs SHA-256
  `365c21c43d8a0b68ca8945e4d3c84e40d36bf81f7ea3bd8976b7b3439d2c0615` (existing harness algorithm: sorted tracked path then
  file bytes, without a separator). All application build inputs are unchanged
  by this issue. Later focused changes strengthen preflight drift checks only;
  documentation/evidence commits do not change runtime/build inputs.
- Redis: `docker.io/dmitryzhuravlev/online-shop-redis-cart@sha256:81be8a1f52db5f99fe3de0bbbd2efce827f51ce409155a95e9bdbac8c2721ba6`.
- Redis kind/platform: single-platform manifest, `linux/amd64`; config/image ID
  `sha256:aa189b5a1954929c393585e6dc5717a75b18f75a931df8bdcc00a3d3bd546be6`. No index identity is claimed for this
  selector. Digest pull and INFO version **7.4.8** passed.
- Runtime: UID/GID 1000:1000, read-only root, dropped capabilities, writable
  project-owned `/data`, CPU 0.125/memory 256 MiB limits, RDB/AOF disabled,
  15-second shutdown budget. Canonical Kubernetes YAML consistency passed,
  including `Recreate`, one replica, resource requests, probes and `emptyDir`.
- Collector Contrib **0.123.0**, Docker Engine **28.5.1**, Compose **2.40.3**.
  Receiver options were checked against the version-pinned upstream `config.go`
  and `metadata.yaml`, then exercised against the actual selected Redis server.

[Sanitized machine-readable evidence](redis-evidence-summary.json) contains exact
local application/probe image IDs, separate application/tooling revisions,
configuration, signal values, phase results and cleanup. Local built images
are validation artifacts, separate from historical published-image mappings.
The real cart release Dockerfile retained trimmed, self-contained, single-file
publishing and chiseled runtime packaging. No application source was modified.

## Executed checks

```text
python workloads/online-shop/validation/otel/test_redis_contract.py
python workloads/online-shop/validation/otel/run_redis.py
python workloads/online-shop/validation/otel/run.py
python -m compileall -q workloads/online-shop/validation/otel
git diff --check
```

- Four drift tests passed, including negative selector/platform, security,
  replica, endpoint and external-storage cases. Both active selectors match the
  existing lock; no tag-only selector or fallback is accepted.
- Exact artifact/platform/config identity; PING; string SET/GET/expiration/delete;
  cache hash fields/read/update/TTL/expiration; explicit persistence settings;
  actual non-root ID, read-only root mount and writable-data checks passed.
- Real cart empty/add/read/quantity update/clear and two-session isolation passed.
- Outage returned `FAILED_PRECONDITION` in **5.944 s**, before
  the 10-second RPC deadline. After Redis readiness, the recovery probe completed
  in **2.108 s**, including probe
  container startup and cart operations. Cart container ID, start time and
  restart count remained unchanged; no cartservice restart was used.
- Redis graceful shutdown exited 0 without OOM in
  **0.810 s**. A process/container restart with the
  same volume retained a synthetic file but lost Redis state, as required by
  disabled RDB/AOF. Full container/volume replacement removed both state and file.
- Exported Redis server metrics had actual positive memory, connection,
  command, uptime and keyspace values; samples stopped during the bounded
  outage and resumed after restoration. Receiver outage diagnostics were present.
- **27** native Redis log records were
  ingested with service/namespace/instance/environment identity and parsed
  timestamps, including startup, graceful shutdown and post-recovery startup.
  Native logs carried no fabricated trace/span IDs.
- **35** logical cache spans were checked for CLIENT
  kind, cart parentage, error status, latency and correlated safe logs. Actual
  request/error/duration values agreed. Privacy canaries were absent from
  captured/exported telemetry. No MONITOR/SLOWLOG or raw-command capture was used.
- Cart operations passed with application SDK disabled and export unavailable;
  infrastructure metrics remained distinguishable and enabled.
- Fresh broader acceptance passed **all five phases**: full shopping/RPC/error/
  concurrency/optional HTTP propagation, disabled SDK, stalled Collector,
  refused Collector and Redis failure. Full phase exported
  **2,307 spans** and
  **2,864 correlated logs**
  across all eleven application/helper services. Parentage, RED values,
  timestamp/severity mapping, privacy, shutdown and cleanup assertions passed.

## Corrected failures and limits

The first focused attempt passed functional checks but failed a native-log
assertion: Redis signal-handler messages use epoch timestamps, unlike regular
server messages. A separate parser fixed this; later clean runs passed. The
first broader attempt passed shopping/RPC/failure/concurrency checks but failed
optional HTTP propagation because the validation-only HTTP fixture did not
consume chunked bodies. Bounded chunk consumption fixed the transport failure;
the unchanged acceptance assertion then passed. Both failed attempts cleaned up.
They are not counted as successful acceptance runs.

No Kubernetes runtime, publication, release eligibility, production load or
live SRE topology is claimed. Existing per-language SDK unit suites were not
rerun because application source is unchanged; release builds and real runtime
acceptance were executed. Cartservice health still does not prove Redis
connectivity. Session IDs, keys, values and raw logs are excluded from committed
evidence. Existing historical evidence and legacy image traceability are intact.

## Cleanup and handoff

Focused cleanup verified **zero project containers (including stopped), networks
and volumes**. The complete broader run returned cleanup exit 0 with no remaining
containers; label-scoped follow-up checks cover its networks/volumes too. Only
investigation-created resources were removed. Built images/cache and ignored
raw evidence remain local; no images were deleted.

[REDIS.md](../../REDIS.md#downstream-handoff) defines CI publication, Container
Platform review/new candidate, later AML digest adoption and SRE digest/topology/
storage/telemetry tasks. A known official comparison digest is not an approved
replacement, and no destination digest is invented. Keep PR Draft; merge and
issue closure remain manual.

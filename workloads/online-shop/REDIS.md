# Redis dependency and runtime contract

`images.lock.json` remains the sole image selection record. The `redis-cart`
component selects the existing mirror by its linux/amd64 **manifest** digest.
`redis.runtime.json` references that mapping and adds runtime requirements plus
the observed config digest (the local Docker image ID), not an index digest.
Publisher lineage remains unresolved. Historical shopping evidence does not
establish source/build provenance; the artifact is not declared broken.

## Runtime

One standalone serving instance per environment; no independent old/new servers
may serve simultaneously. AML Kubernetes uses one replica and `Recreate`.
There is no replication, Sentinel or Cluster. DNS is `redis-cart:6379` in AML
and `redis:6379` in the current SRE configuration; downstream adoption must
preserve or explicitly map the cartservice endpoint. No host Redis port is needed.

Run UID/GID 1000:1000 with a read-only root, dropped capabilities, no privilege
escalation, and writable `/data`. Kubernetes uses fsGroup 1000 and `emptyDir`;
Compose uses a project-scoped disposable volume, with a network-isolated,
CHOWN-only setup container using the same Redis artifact to emulate fsGroup.
The setup container is a validation helper, not an application build.
CPU/memory requests and limits are recorded in the runtime contract. Compose
enforces the limits; Kubernetes also declares requests. TCP Kubernetes probes
check the socket; Compose PING checks Redis protocol readiness. Neither claims
the cart workflow works. Cartservice's existing health response reports process
service availability: `RedisCartStore.Ping()` does not contact Redis. This issue
does not redesign health or introduce dependency-driven restart loops.

Explicit `redis-server --save '' --appendonly no` disables RDB and AOF. Carts
are memory-only: **Redis process restart loses carts even when `/data` survives**.
Complete storage replacement also loses carts and diagnostic marker files.
No durability across either event is promised. Graceful SIGTERM shutdown has a
15-second budget. This makes the previous harness persistence choice explicit
in the canonical AML profile; it changes the manifest's implicit RDB default.

The pinned .NET cache package 9.0.11 uses hash reads/writes for `absexp`,
`sldexp`, `data`, with expiration operations when requested. Actual cart writes
set no TTL. Clear writes an empty protobuf cart rather than deleting the key.
The native probe covers strings, expiry, deletion and these hash semantics;
the integration probe uses the real trimmed/self-contained release cartservice,
two synthetic sessions, quantity addition, clear, bounded outage and recovery
through the same running cartservice. No mock or memory backend qualifies.

## Observability

Collector Contrib stays at 0.123.0. Its version-specific Redis receiver collects
INFO-based metrics: memory, connections, CPU, commands, uptime and keyspace
statistics. A separate native Redis stdout regex pipeline captures server
startup/shutdown logs. Both use service `redis-cart`, namespace `online-shop`,
unique project instance and environment `local-validation`. Docker stdout is
copied to a dedicated local file; no Docker socket is mounted in Collector.
Kubernetes collection is a downstream SRE task, not deployed by this manifest.

Application logical `cache.read`/`cache.write` CLIENT spans retain cart parentage,
latency/error measurements and correlated safe logs. They represent cache API
operations, not individual wire commands. Redis produces no synthetic SERVER
spans or trace-correlated native logs. No MONITOR, SLOWLOG, keys, values, session
IDs or raw command arguments are exported. Native logs are operational text;
retain bounded access/retention and do not enable command logging.

Disabling the application SDK does not disable infrastructure metrics. Assertions
separate those identities; unavailable application export must not break cart
operations or shopping. Receiver outage diagnostics, absence of server samples
during outage and resumed samples after recovery are checked independently.

## Reproduction and evidence

From a clean committed source/tooling revision and a running local linux/amd64
Docker engine:

```text
python workloads/online-shop/validation/otel/test_redis_contract.py
python workloads/online-shop/validation/otel/run_redis.py
python workloads/online-shop/validation/otel/run.py
```

The first command needs only Compose configuration rendering. The focused runner
pulls the exact mirror, builds cartservice and probe, and runs isolated internal
checks without public ports. It records separate application revision/input hash,
validation tooling revision, image IDs, timing, signals and verified scoped
cleanup in ignored `validation/otel/output/<project>/redis-result.json`.
The last command is the broader eleven-service acceptance harness. Do not infer
a fresh complete run from focused checks. Historical `RESULTS.md` and evidence
summaries remain unchanged and used the official `redis:7.4.8-alpine` selector.
See `validation/otel/REDIS-RESULTS.md` for newly executed evidence.

## Downstream handoff

Related to AML #23 and #21. Cross-project canonicalization is not complete here.

1. CI Build Platform: review an official supported version, license and update
   policy; publish a fresh traceable mirror in the existing
   `docker.io/dmitryzhuravlev/online-shop-redis-cart` repository. Record exact
   upstream index/platform/config identities, destination digest and actual run
   evidence. A known comparison digest is not version approval.
2. Container Platform: independently review that dependency and create a new
   candidate under existing eligibility policy. Preserve immutable baseline
   candidates, observations and legacy status; no provenance is invented.
3. AML: adopt the actually published verified digest through the image mapping,
   update config identity and rerun relevant contract/runtime/telemetry checks.
4. SRE Platform: implement effective digest rendering, singleton/update semantics,
   ephemeral writable storage/security and version-compatible Redis metrics and
   stdout collection. Remove generic HTTP `/metrics` scraping of native port
   6379. Render and validate every environment; do not infer live cluster state.

Later retirement of mutable tags/old images requires a consumer and rollback
reference audit first. Frozen experiments and historical evidence are excluded
from automatic reference replacement. No image publication/deletion, downstream
repository change or deployment is part of this AML issue.

Existing downstream context: [Container Platform baseline #3](https://github.com/DimitryZH/container-platform/issues/3),
[runtime smoke #13](https://github.com/DimitryZH/container-platform/issues/13),
and [SRE staging baseline #11](https://github.com/DimitryZH/sre-platform/issues/11).
The four handoffs above are requirements for subsequent owner tasks, not claims
that those tasks have been created, approved or completed.

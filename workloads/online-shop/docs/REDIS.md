# Redis dependency and runtime contract

Inline file paths are workload-relative unless stated otherwise. Commands retain their original working directory; commands beginning with `workloads/online-shop/` run from the repository root. Markdown links are document-relative.

`images.lock.json` selects the proposed canonical linux/amd64 manifest. The
source is Docker Official Image `docker.io/library/redis:7.4.12-alpine3.21`.
[redis.source-v2.json](../redis.source-v2.json) pins upstream index, platform/config,
Dockerfile source and index-bound BuildKit provenance. The trust basis is the
Docker Official Images metadata plus Docker Hub `library/redis` publication;
the unsigned provenance is not claimed as a verified publisher signature.

The expected canonical reference is
`docker.io/dmitryzhuravlev/online-shop-redis-cart@sha256:1cf73a2f04808e55a8bd2f5706c2aa0ebb0f71938f93deb7af79f48311cd5cb9`.
Publication and independent equality verification remain pending. The existing
image remains available; its immutable reference is retained in `previousImage`.
`redis.runtime.json` supplies the matching config digest and runtime settings.
A planned reference is not evidence that the image has been published or admitted.

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

## SDP handoff

This dependency-only update is coordinated with SDP #100. Application source and
build inputs remain unchanged. After both review branches merge, copy only the
pinned official linux/amd64 manifest to the new canonical version reference,
preserving its digest; do not overwrite a mutable existing tag or remove an image.
Independently verify canonical content before copying the same manifest to SDP's
approved Artifact Registry. SDP must repeat official/source/content/canonical
verification before required-attestor signing, then read back occurrence/signature.
No publication, signing or deployment was performed for this change.

Redis runtime settings and cartservice contracts are unchanged: UID/GID 1000,
read-only root with writable /data, singleton Recreate, ephemeral persistence,
6379 and the existing .NET hash/expiry operations. The official server/CLI files
are world-executable; the non-root Compose entrypoint does not invoke root-only
ownership handling. Exact version assertions read `redisVersion` from the contract.
Run contract tests locally; a running Linux Docker engine is required for fresh
real cart/restart/telemetry acceptance. Old evidence is not a new runtime result.

# Stage D: Aspire Runtime Validation

## Result

**PASS with documented baseline limitations**

The complete Experiment 05 Aspire AppHost started successfully and reached a
stable 29-resource runtime state. All required public endpoints returned HTTP
200, the basic storefront workflow worked, Kafka contained the `orders` topic,
accounting consumed generated orders, and the Collector processed traces,
metrics, and logs.

## Preflight

- Working tree was clean before Stage D changes.
- .NET SDK: `10.0.109`
- Aspire: `13.3.5`
- Initial `dotnet build`: PASS with the existing `NU1903` warning for
  `MessagePack 2.5.192`.
- The Stage A four-layer Compose deployment was still running with all 29
  containers and occupied stable ports `8080`, `10000`, and `9090`.
- The DevBox had approximately 1.8 GiB available memory and no swap before the
  transition.

## Stage A Stack Transition

The Stage A deployment was stopped cleanly with its four Compose files before
starting Aspire. Containers and the Compose network were removed, while images
and volumes were preserved.

## Runtime Parameters

All five required parameters were supplied through process-local environment
configuration:

- `postgres-password`
- `astronomy-user-password`
- `monitoring-user-password`
- `openai-api-key`
- `flagd-ui-secret`

Only safe development values were used. Values were not written to tracked
files or this report. Runtime validation confirmed that `flagd-ui-secret` must
be at least 64 bytes for the Phoenix cookie store.

## Startup Result

- DCP API server: PASS; no prior DCP startup timeout reproduced.
- Aspire Dashboard: started on `http://localhost:15405`.
- Extended readiness: required for Kafka and OpenSearch.
- Final AppHost state: `Distributed application started`.
- Final Docker state:
  - 29 containers created;
  - 29 containers running;
  - 0 unhealthy containers;
  - 0 exited containers;
  - 0 containers in restarting state at the observation point.

The DevBox uses `umask 0077`, which left copied configuration assets as
`0600/0700`. Non-root backend containers initially failed to read their bind
mounts. Working-tree asset permissions were corrected to the documented
`0644/0755` runtime contract before the successful run. This was classified as
a DevBox checkout/environment issue; no secret or configuration content was
changed.

## Focused Runtime Fixes

1. Modeled the frontend service endpoint as HTTP and replaced its Docker
   `CMD-SHELL` health command with an Aspire HTTP health check. The pinned
   distroless frontend image does not contain `/bin/sh`.
2. Preserved `restart: unless-stopped` behavior for `checkout` and
   `fraud-detection`. Checkout can encounter the upstream Kafka-producer startup
   race, and fraud-detection retains its known upstream flagd resolver failure.

Checkout restarted once after the known producer initialization race and then
continued serving requests. Fraud-detection continued reproducing the Stage A
flagd resolver restart behavior.

## Resource Validation

| Resource or layer | Result | Evidence |
| --- | --- | --- |
| PostgreSQL | PASS | Running; application schema-backed product APIs worked |
| Valkey | PASS | Running; cart API returned HTTP 200 |
| Kafka | PASS | Healthy; `__consumer_offsets` and `orders` topics present |
| OpenSearch | PASS | Healthy after extended readiness; telemetry log index present |
| Prometheus | PASS | Healthy; 382 metric names observed |
| Jaeger | PASS | Running; 24 service-name entries observed |
| Grafana | PASS | Running and reachable through frontend-proxy |
| Collector | PASS | Running; debug exporter showed traces, metrics, and logs |
| Accounting | PASS | Logs contained consumed order details |
| Checkout | PASS with recovery | Restarted once, then remained running |
| Fraud detection | Baseline limitation | Known flagd resolver restart behavior reproduced |

At the final observation point, the stack used approximately 5.2 GiB of the
7.8 GiB DevBox memory, with approximately 2.6 GiB available and no swap.

## Endpoint Validation

| Endpoint | Result |
| --- | --- |
| `http://localhost:8080/` | HTTP 200 |
| `http://localhost:8080/grafana/` | HTTP 200 |
| `http://localhost:8080/jaeger/ui/` | HTTP 200 |
| `http://localhost:8080/loadgen/` | HTTP 200 |
| `http://localhost:8080/feature/` | HTTP 200 |
| `http://localhost:8080/telemetry/` | HTTP 200 |
| `http://localhost:9090/-/healthy` | HTTP 200 |

## Functional Smoke Validation

- Storefront root: PASS.
- Product catalog API: HTTP 200 with 10 products.
- Product detail page: HTTP 200.
- Cart read API: HTTP 200.
- Load Generator cart additions: successful requests observed.
- Checkout: successful requests and accounting-consumed order details observed
  after checkout automatic recovery.
- Kafka order path: `orders` topic present.

The Load Generator continued to report HTTP 500 failures, including failures
during the startup window. Zero failures were not required, and this behavior
is consistent with the Stage A baseline limitation.

## Issue Classification

| Issue | Classification | Outcome |
| --- | --- | --- |
| Restrictive copied-asset permissions | DevBox environment issue | Corrected in working tree for runtime validation |
| Frontend Docker health command requires missing `/bin/sh` | Migration issue | Fixed with HTTP endpoint modeling and Aspire health check |
| Checkout exits after early Kafka producer race | Source/startup behavior plus missing migration restart policy | Restart policy preserved; service recovered |
| Fraud-detection flagd resolver error | Known Stage A baseline limitation | Restart policy preserved; limitation remains |
| Transient Kafka and Collector export errors during startup | Known Stage A baseline limitation | Recovered after dependencies became ready |
| Collector host process scrape warnings | Known Stage A baseline limitation | Documented; signal pipelines remained active |
| `MessagePack 2.5.192` `NU1903` warning | Existing dependency risk | Unchanged |

## Runtime State and Cost

The Aspire AppHost and all 29 containers remain running for follow-up
inspection. They are bound to localhost and do not create new cloud resources,
but the active DevBox continues consuming CPU and memory and continues to incur
the normal DevBox VM cost while it remains running.

## Stage D Status

**PASS with documented baseline limitations**

The full Aspire topology starts, stabilizes, serves all required endpoints, and
supports the primary storefront, Kafka, and telemetry runtime paths. Detailed
observability equivalence remains reserved for Stage E.

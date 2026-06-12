# Stage C.3: Kafka and Accounting Layer Report

## Result

**PASS**

Stage C.3 added the Kafka broker and first messaging consumer to the
Experiment 05 Aspire AppHost. Build, static topology, and isolated targeted
runtime validation passed. The Stage A Compose stack remained running and was
not modified.

## Resources Added

| Resource | Representation | Image |
| --- | --- | --- |
| `kafka` | Explicit container | `ghcr.io/open-telemetry/demo:latest-kafka`, pinned by Stage A digest |
| `accounting` | Explicit container | `ghcr.io/open-telemetry/demo:latest-accounting`, pinned by Stage A digest |

No checkout producer, fraud-detection consumer, Collector, observability
backend, frontend, load-generator, or other application service was added.

## Image Lock

`aspire/image-lock.json` now contains six entries. Stage C.3 adds:

- `kafka` at digest
  `sha256:4baa7327e27617fca641e09417d9e1442c6511f665548b5c4f4598ea25338194`;
- `accounting` at digest
  `sha256:393f062da55d4311a01919d4c130e440d9cb57bcd9f8e7ded6d5bbdf8cb8b2ab`.

Both digests and image IDs were captured from the running Stage A containers.
No credentials or secret values were added to the image inventory.

## Kafka Representation

Kafka remains an explicit container using the exact instrumented Stage A demo
image. The resource preserves:

- single-broker KRaft broker/controller behavior;
- broker listener `PLAINTEXT://kafka:9092`;
- controller listener `CONTROLLER://kafka:9093`;
- controller quorum voter `1@kafka:9093`;
- named Aspire endpoints for broker port `9092` and controller port `9093`;
- topic auto-creation and replication-factor-one defaults embedded in the
  instrumented image;
- embedded Java agent and JMX target configuration;
- Compose heap settings;
- OpenTelemetry HTTP exporter and resource environment intent;
- a Docker TCP health check equivalent to `nc -z kafka 9092`.

The health check is supplied through container runtime arguments. Accounting
uses `WaitFor(kafka)`, so it waits for Kafka readiness rather than only process
start.

## Accounting Representation

Accounting remains an explicit container using the exact Stage A consumer
image. The resource preserves:

- `KAFKA_ADDR=kafka:9092`;
- the `accounting` consumer group and `orders` subscription embedded in the
  image;
- the `astronomy_user` PostgreSQL connection contract;
- the secret-backed `astronomy-user-password` Aspire parameter in the database
  connection expression;
- OpenTelemetry HTTP exporter, resource, service-name, and Entity Framework
  instrumentation settings;
- a Kafka endpoint reference and readiness dependency;
- an astronomy-db endpoint reference and process-start dependency.

The Collector remains intentionally absent until Stage C.5. Accounting and
Kafka therefore preserve their OTLP configuration while tolerating expected
temporary export failures.

## Build Validation

Commands executed from `experiments/05-opentelemetry-demo/aspire/`:

```bash
dotnet build
dotnet build --no-restore
```

Both builds succeeded with zero errors. The existing `NU1903` warning remains
for the transitive `MessagePack 2.5.192` dependency.

The first sandboxed build attempt could not access `api.nuget.org`. Repeating
the required build with DevBox network access completed successfully.

## Static Topology Validation

Aspire manifest publication succeeded and confirmed:

- six container resources through Stage C.3;
- immutable digest references for Kafka and accounting;
- Kafka broker and controller endpoints;
- the resolved Kafka environment contract;
- the accounting Kafka endpoint reference;
- the accounting astronomy-db endpoint reference;
- the PostgreSQL password remains an Aspire secret expression.

As in Stage C.2, the manifest publisher logged a sandbox-only auxiliary
backchannel socket permission error after writing the manifest.

## Targeted Runtime Validation

Targeted validation used temporary containers on an isolated
`exp05-c3-validation` Docker network. It did not connect to or modify the
Stage A Compose network.

Validation confirmed:

- the exact instrumented Kafka image starts in single-broker KRaft mode;
- Kafka eventually reports `healthy` using `nc -z kafka 9092`;
- the broker starts with Kafka version `4.2.0`;
- the Java agent reports version `2.28.1`;
- the isolated PostgreSQL initialization completes and accepts connections;
- accounting remains running with its intended Kafka and PostgreSQL
  environment;
- accounting logs `Connecting to Kafka: kafka:9092`;
- no accounting failure occurred due to missing basic configuration.

Kafka required an extended startup window before becoming healthy. Temporary
Kafka telemetry export errors for the intentionally absent Collector matched
the Stage A baseline expectation.

Accounting reported:

```text
Subscribed topic not available: orders: Broker: Unknown topic or partition
```

This is expected at Stage C.3 because checkout, the producer path, is
intentionally deferred. The isolated broker contained only
`__consumer_offsets`; no order event was produced or consumed.

All temporary Stage C.3 validation containers and the isolated network were
removed after validation.

## Known Issues and Remaining Risks

1. Kafka startup is slow enough to become temporarily unhealthy before
   recovering. Later full-AppHost validation must allow an extended readiness
   window and avoid unnecessary recreation.
2. The `orders` topic and accounting database writes cannot be validated until
   checkout is added as the producer path.
3. Kafka and accounting emit expected OTLP export failures while the Collector
   is absent.
4. Full AppHost runtime validation remains deferred; the prior DevBox DCP
   API-server timeout must be reassessed in later stages.
5. The existing transitive `MessagePack 2.5.192` `NU1903` warning remains.
6. Stage C.4 must add only the observability backends and must not change the
   Kafka or accounting contracts.

## Scope and Hygiene Confirmation

- No fraud-detection, checkout, Collector, observability backend, frontend, or
  load-generator resource was added.
- No upstream source or Compose file was modified.
- The pinned upstream checkout remained clean.
- No secrets, tokens, external IPs, SSH fingerprints, or personal identity
  values were added.

## Suggested Commit Message

```text
feat(experiment-05): add Aspire Kafka layer
```

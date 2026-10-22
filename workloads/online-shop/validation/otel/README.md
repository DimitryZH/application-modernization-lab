# Isolated Online Shop telemetry validation

Prerequisites: Docker Engine with Linux amd64 containers, Docker Compose v2, Python 3 on the host, Git, package-registry network access, and enough memory/disk for eleven source builds. No host Go, Java, Node, Python application dependencies or .NET SDK is required.

From the repository root:

```powershell
python workloads/online-shop/validation/otel/run.py
```

The command builds every application/helper image locally, starts a uniquely named Compose project, runs scenarios and assertions, then removes only that project's containers/network/ephemeral storage. It never publishes images or changes the canonical Kubernetes manifest. Source labels must match for `--skip-build` reuse. `--only full|disabled|unavailable|refused|redis` selects one phase. Output lives under ignored `output/<project>/` and failures exit nonzero. Preserve the directory when reporting a failure.

Phases cover shopping and all business RPCs, checkout context continuity, direct RPCs outside checkout, error/fallback paths, 20 concurrent requests, sampling, optional outbound HTTP propagation, load-generator telemetry, disabled telemetry, stalled/refused Collector endpoints, Redis failure, graceful shutdown, and cleanup. A transparent validation-only gRPC proxy injects failures and forwards trace metadata; no failure flags are added to application code.

Collector has OTLP/gRPC plus structured stdout ingestion. Its three file exporters provide machine-readable traces, metrics and correlated logs. `assertions.py` checks resource coverage, parentage, duplicate spans, exact RED counter values/attributes and duration counts, native LogRecord timestamp/severity mapping, privacy canaries, failure events and log correlation. Raw logs are retained separately, including records rejected from ingestion. Assertions require evidence rather than initialization text or HTTP status alone.

Each run records application image IDs and source fingerprints. Existing published image mappings remain historical. Cartservice is built with its real release Dockerfile and tested against Redis, including traces/metrics/logs; in-memory unit tests cannot replace that gate.

Cleanup destroys only synthetic data created by this run. Built images and Docker build caches remain reusable; evidence remains on disk. Inspect `cleanup.json` for the cleanup result.

The full acceptance check uses the existing app behavior: shipping/email are simulated, payment is a local demo, and tolerated failures can leave an accepted order with a retained cart or failed confirmation. Tests assert these differences explicitly.

Unit tests can be reproduced after image builds:

```powershell
python workloads/online-shop/validation/otel/unit.py
```

These use disposable containers and read-only source mounts, copying compilation inputs into container-local temporary directories. Named Go/NuGet dependency caches remain reusable; no application stack is started. Java tests also run during its release image build.

Regression suites use real in-memory SDK exporters/readers to assert a failed operation's span status, request/error deltas, histogram count, completion log outcome and trace/span correlation. Cases include HTTP 503/404, returned status 0 and raised transport errors, server/client status semantics, nonexception gRPC failure, Node/Java error dimensions, and diagnostic severity/category/privacy. Acceptance additionally checks cumulative RED series equality after shutdown across all languages.

# Online Shop manual OpenTelemetry

Inline file paths are workload-relative unless stated otherwise. Commands retain their original working directory; commands beginning with `workloads/online-shop/` run from the repository root. Markdown links are document-relative.

Issue: [#21](https://github.com/DimitryZH/application-modernization-lab/issues/21).

The ten application services and load generator initialize OpenTelemetry explicitly in source. Handwritten HTTP/gRPC wrappers own transport spans, request counters, error counters, duration histograms and context propagation. Selected handlers own business spans and operation counters. There are no injected agents, bytecode agents, OTel monkey patches or automatic instrumentation bundles. Existing Locust/gevent scheduling remains application runtime behavior.

## Ownership and topology

Frontend calls checkout, catalog, cart, currency, shipping, recommendation and ads. Checkout calls catalog, cart, currency, payment, shipping and dummy email. Recommendation calls catalog. Cart wraps logical IDistributedCache reads/writes; Redis has no local instrumentation. Optional frontend packaging and assistant HTTP calls carry the request context and have bounded HTTP clients.

Cartservice retains ASP.NET's `Microsoft.AspNetCore` SERVER Activity. The manual gRPC interceptor enriches that Activity and creates an INTERNAL business Activity, never a second SERVER Activity. Custom storage Activities are CLIENT spans. Framework log providers are replaced with a safe diagnostic provider. The existing self-contained, single-file, fully trimmed chiseled release format is retained.

All other HTTP/gRPC server/client spans have handwritten ownership. Health/reflection traffic is excluded from manual transport wrappers; native ASP.NET health Activities can still exist. Only unary application RPCs exist. Unsupported health Watch behavior is preserved.

## Configuration

| Variable | Meaning/default |
|---|---|
| `ONLINE_SHOP_TELEMETRY_ENABLED` | `true`/`1` enables SDK exporters; default off |
| `OTEL_SDK_DISABLED` | `true` overrides enablement |
| `ENABLE_TRACING` | Legacy enable alias when the master switch is absent |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP/gRPC Collector URL; SDK localhost default |
| `COLLECTOR_SERVICE_ADDR` | Deprecated endpoint fallback in services that previously used it |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Set `grpc` for this implementation |
| `OTEL_TRACES_EXPORTER`, `OTEL_METRICS_EXPORTER` | `none` disables that signal; otherwise OTLP |
| `OTEL_TRACES_SAMPLER_ARG` | Parent-based root probability, default `0.1`; validation `1` |
| `OTEL_METRIC_EXPORT_INTERVAL` | Milliseconds, minimum 1000, default 10000 |
| `ONLINE_SHOP_VERSION` | Source/build identity; default `development` |
| `ONLINE_SHOP_ENVIRONMENT` | Resource deployment environment; default `local` |

Service names are fixed to component IDs and namespace to `online-shop`; they cannot accidentally change with an unrelated process environment. SDK-specific settings beyond this table are not a portable configuration promise. Plain HTTP Collector URLs are for an isolated local network. HTTPS endpoints use SDK/system TLS trust. Do not pass secrets through resource attributes or version strings.

The local runner labels newly built images with the Git revision/dirty state and a hash of application/protocol inputs, and verifies those labels before reuse. This is local build evidence, not a publisher attestation. Historical `images.lock.json` records and published image references are untouched.

## Traces and metrics

W3C tracecontext extraction/injection preserves trace IDs, tracestate and upstream sampling decisions. Baggage is not forwarded by manual wrappers. Browser navigation requests are independent traces; a checkout request retains one distributed context, including currency calls. Callback/worker/async scopes are restored after use. Disabled Python explicitly retains a non-recording parent, since its no-op tracer alone does not preserve an explicitly supplied parent.

Transport span names are HTTP method plus route template, or the existing `hipstershop.Service/Method` protocol identifier. Business spans identify operations, not individual functions. Errors record bounded status/type and safe summaries, never exception objects or raw messages. Handled ad/recommendation/email/cart-clear failures retain existing application behavior and produce failure/degradation telemetry. Email remains a dummy confirmation service; shipping remains simulated with its existing quote.

A small metric vocabulary uses bounded `operation`, `kind` and `outcome` dimensions:

- `online_shop.transport.requests`: `{request}`, by server/client operation.
- `online_shop.transport.errors`: `{request}`, failed transport operations.
- `online_shop.transport.duration`: seconds, boundaries `.005,.01,.025,.05,.1,.25,.5,1,2.5,5,10`.
- `online_shop.business.operations`: `{operation}`, handler/business completions and degradation events.

All three transport instruments use the **same exact** attributes: `operation`, `kind`, `outcome`. `kind` is `server`, `client`, or `internal`; operation names and outcome classifications come from fixed routes, methods and code-defined classifications. A failed request contributes one request, one error and one duration observation with identical attributes. Successful requests and cache misses contribute no errors. RED queries can filter/group the numerator and denominator identically (aggregate over `outcome` for an overall error ratio).

HTTP clients classify 4xx as `http_4xx`, 5xx as `http_5xx`, and network failures (including Locust status 0) as `transport_error`. HTTP servers classify only 5xx as failed; 4xx remains an expected rejection. Response objects, returned errors, application responses and tolerated failure behavior are unchanged. The span status/error type, metric observations and completion log derive from the same outcome. Python RPCs explicitly returning a non-OK gRPC context status are counted as failures even without a raised exception.

Python also describes INTERNAL work using the same operation/kind vocabulary. Query `kind=server` or `kind=client` for transport RED measurements. Business operation labels distinguish accepted/rejected checkout, payment rejection classes, cart mutations, conversion, catalog access, recommendations, shipping and dummy confirmation. Cache read misses are normal outcomes rather than transport errors. This common metric family replaces the report's proposed many service-specific names while retaining explicit operation ownership and bounded dimensions.

No IDs, URLs, search strings, payment details, amounts, addresses, email, cookies, request bodies, Redis keys or arbitrary exception messages belong in telemetry. Raw metric dimensions never come from request data. Version/environment/resource configuration is trusted operator input.

## Logs

Applications emit one-line JSON to stdout. Contextual records contain timestamp, severity, event, operation, outcome, canonical service identity and valid trace/span IDs. Legacy diagnostic adapters discard raw messages and arbitrary fields while retaining severity, an allowlisted category (`startup`, `configuration`, `dependency`, `application`), a stable `<category>.diagnostic` event, bounded `error.type`, and active trace/span context. Call sites explicitly select categories; adapters do not classify untrusted message text. Unclassified legacy records use `application`. Go handlers pass context explicitly, Node/Python/Java use their scoped context, and cartservice retains `Activity.Current`. WARN/ERROR/FATAL remain distinct. Explicit completion records classify dependency/client failures separately from application/server failures. No SDK log exporter or logging bridge duplicates stdout export.

The local host runner captures only its own project containers' Docker stdout/stderr, preserves raw evidence, and forwards structured application lines to files read by Collector's filelog receiver. Collector maps application timestamps and severity into native OTLP LogRecord time/severity fields, alongside trace/span identifiers and resource identity, then writes OTLP JSON evidence. It does not require a Docker socket mount or privileged access. Collection is controlled by the validation runner; disabling SDK export does not suppress ordinary application logging.

## Lifecycle and limitations

Trace queues are bounded to 512 records with batches of 128 and a one-second schedule. Export calls have short timeouts; failures do not become request failures. Metric attributes are finite operation/status sets. SDK buffering/retry APIs differ by language; no common log SDK or durable telemetry spool is assumed. Export failure may lose telemetry by design.

Termination stops serving/drains work and flushes providers within container grace periods. Validation asserts normal exit rather than accepting a forced kill. Python additionally uses a shutdown watchdog. Java callback scopes, Node AsyncLocalStorage, Python handler scopes and .NET Activities are explicitly owned.

Optional cloud catalog/Spanner/AlloyDB paths remain selectable and are not deployed or live-tested here. Their operation boundaries and sensitive diagnostics are covered, but Redis is the acceptance profile. Existing unrelated concurrency/storage semantics are preserved.

## Material design refinements

- .NET OTel 1.15.3 replaces proposed 1.12.0 after restore reported security advisories; packaging flags are unchanged.
- Node builder/runtime both use 20.17.0: the existing profiler native addon failed against Node 22. No profiler is enabled in validation.
- Python email/recommendation use the same pinned Python 3.12 slim base to obtain compatible wheels; requirement inputs and resolved locks now agree.
- Java start-script outputs are separated because adding tests exposed Gradle's overlapping-output validation. Runtime distribution paths are unchanged.
- Docker build caches preserve dependency/compiler work without changing individual service build contexts.

See [validation instructions](../validation/otel/README.md) and [implementation evidence](../validation/otel/RESULTS.md).

## Redis server collection

[REDIS.md](REDIS.md) defines the current external dependency and its focused
acceptance path. Collector 0.123.0 collects Redis INFO metrics and parses native
server stdout with a separate resource identity. Application logical cache CLIENT
spans remain distinct from Redis command execution; no Redis SERVER spans or
trace-correlated native server logs are generated. Infrastructure metrics can
remain present while application SDK export is disabled or unavailable. New
results live in [Redis evidence](../validation/otel/REDIS-RESULTS.md); earlier
application telemetry evidence retains its original Redis selection and scope.

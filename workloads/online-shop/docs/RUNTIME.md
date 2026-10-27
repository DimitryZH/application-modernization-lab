# Portable runtime handoff

Inline file paths are workload-relative unless stated otherwise. Commands retain their original working directory; commands beginning with `workloads/online-shop/` run from the repository root. Markdown links are document-relative.

These are application requirements, independent of the validation Compose file.
Use service DNS names appropriate to the consuming platform. RPC endpoints are
plaintext gRPC `host:port`; HTTP URLs include a scheme. There are no mandatory
cloud credentials in the portable profile. [TELEMETRY.md](TELEMETRY.md) owns signal
semantics, privacy, counters and lifecycle evidence; this document supplies
per-runtime configuration differences. Build contexts/arguments belong to
[BUILDING.md](BUILDING.md).

## Application settings

All ports below are container ports; host publication is a platform decision.
No application Dockerfile provides a dependency-aware health/startup gate.
Consumers must supply reachable dependencies and readiness policy.

| Component | Listen setting/default | Required endpoints | Optional settings and portable profile |
|---|---|---|---|
| adservice | `PORT=9555`, gRPC | none | Java profiler download/start is commented out; no cloud agent required |
| cartservice | `ASPNETCORE_HTTP_PORTS=7070`, HTTP/2 gRPC; ASP.NET URL/Kestrel settings can override | set `REDIS_ADDR=redis-cart:6379` for the accepted profile | Backend precedence Redis, Spanner, AlloyDB, in-memory. Leave Spanner/AlloyDB settings unset; no persistent cart storage in accepted profile. Runs UID 1000 in chiseled image |
| checkoutservice | `PORT=5050`, gRPC | `SHIPPING_SERVICE_ADDR`, `PRODUCT_CATALOG_SERVICE_ADDR`, `CART_SERVICE_ADDR`, `CURRENCY_SERVICE_ADDR`, `EMAIL_SERVICE_ADDR`, `PAYMENT_SERVICE_ADDR` | leave `ENABLE_PROFILER` unset (only `1` enables) |
| currencyservice | required `PORT`, normally 7000, gRPC | none | `DISABLE_PROFILER=1`; tracked conversion JSON; profiler otherwise attempts cloud startup |
| emailservice | `PORT=8080`, gRPC | none | `DISABLE_PROFILER=1` (presence disables); Docker sets legacy `ENABLE_PROFILER=1`, but the server checks DISABLE_PROFILER. Dummy confirmation, not SMTP |
| frontend | `PORT=8080`, HTTP; `LISTEN_ADDR` default all interfaces | `PRODUCT_CATALOG_SERVICE_ADDR`, `CURRENCY_SERVICE_ADDR`, `CART_SERVICE_ADDR`, `RECOMMENDATION_SERVICE_ADDR`, `CHECKOUT_SERVICE_ADDR`, `SHIPPING_SERVICE_ADDR`, `AD_SERVICE_ADDR`; also nonempty `SHOPPING_ASSISTANT_SERVICE_ADDR` even with assistant UI off | leave `ENABLE_PROFILER` unset; `ENABLE_ASSISTANT=false`; `PACKAGING_SERVICE_URL` absent disables optional HTTP call; assistant address is `host:port` (handler prepends `http://`), only called for assistant routes. A consumer can supply its intended optional endpoint without deploying a fake service |
| loadgenerator | no required listener; headless Locust | `FRONTEND_ADDR=frontend:8080` (no scheme; entrypoint adds `http://`) | `USERS=10`, `RATE=1` by entrypoint; `GEVENT_SUPPORT=True`; synthetic helper, optional in a release |
| paymentservice | required `PORT`, normally 50051, gRPC | none | `DISABLE_PROFILER=1`; simulated payment provider |
| productcatalogservice | `PORT=3550`, gRPC | none for local JSON catalog | `DISABLE_PROFILER=1`; leave `ALLOYDB_CLUSTER_NAME` unset for local `products.json`; `EXTRA_LATENCY` optional Go duration, unset normally |
| recommendationservice | `PORT=8080`, gRPC | `PRODUCT_CATALOG_SERVICE_ADDR` | `DISABLE_PROFILER=1` (presence); recommendations call catalog |
| shippingservice | `PORT=50051`, gRPC; Docker `APP_PORT` is unused by source | none | `DISABLE_PROFILER=1`; simulated shipping quote |

Frontend optional UI settings: `BASE_URL` default empty route prefix,
`FRONTEND_MESSAGE`, `BANNER_COLOR`, `ENV_PLATFORM` default empty;
`CYMBAL_BRANDING` and `ENABLE_SINGLE_SHARED_SESSION` default false. It probes GCP
metadata asynchronously for display details even outside GCP; that is not a
required application dependency. Packaging/assistant calls have bounded HTTP
clients; those optional backends are not provided by AML's eleven builds.

For cloud profiles, cart Spanner uses `SPANNER_CONNECTION_STRING` or
`SPANNER_PROJECT`, `SPANNER_INSTANCE`, `SPANNER_DATABASE`; AlloyDB uses
`ALLOYDB_PRIMARY_IP`, `PROJECT_ID`, `ALLOYDB_SECRET_NAME`, `ALLOYDB_DATABASE_NAME`,
`ALLOYDB_TABLE_NAME`. Catalog AlloyDB uses `PROJECT_ID`, `REGION`,
`ALLOYDB_CLUSTER_NAME`, `ALLOYDB_INSTANCE_NAME`, `ALLOYDB_DATABASE_NAME`,
`ALLOYDB_TABLE_NAME`, `ALLOYDB_SECRET_NAME`. These require cloud credentials,
Secret Manager/network access and are not live-validated by the accepted evidence.
Python profilers require `GCP_PROJECT_ID` when enabled. Go/Node profiler SDKs use
their cloud credential/metadata discovery. Keep them disabled for portable use.

## Telemetry by runtime

For every component use `ONLINE_SHOP_TELEMETRY_ENABLED=true`,
`OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317`, and
`OTEL_EXPORTER_OTLP_PROTOCOL=grpc` for the portable enabled profile. Use HTTPS with
system/SDK trust for encrypted export. Do not append `/v1/traces` or `/v1/metrics`
to gRPC endpoints. Protocol environment variables do not switch the explicitly
constructed Go/Node/Python/Java exporters to HTTP. .NET's SDK options can interpret
protocol settings; only gRPC is covered here. Leave signal-specific SDK endpoint
overrides unset for a uniform endpoint. No generic OTEL_* behavior is promised.

| Components/runtime | Enablement and endpoint differences |
|---|---|
| frontend, checkoutservice, productcatalogservice, shippingservice / Go | `OTEL_SDK_DISABLED=true` wins; explicit master switch `true`/`1` next; otherwise `ENABLE_TRACING=1` only when `DISABLE_TRACING` empty. Standard SDK endpoint takes precedence. Legacy `COLLECTOR_SERVICE_ADDR` fallback applies to traces only, uses `host:port` and forces insecure; metrics does not use that fallback. Prefer standard URL for both signals |
| currencyservice, paymentservice / Node | SDK-disabled wins; explicit master switch next; otherwise legacy `ENABLE_TRACING=1`. Legacy collector fallback becomes general endpoint, prepending `http://` to bare host:port; per-signal SDK endpoints can override |
| emailservice, recommendationservice, loadgenerator / Python | same switch precedence as Node. Legacy fallback similarly normalizes to general URL. gRPC SDK insecure/TLS behavior derives from endpoint scheme or SDK signal-specific insecure options; leave those overrides unset for the portable profile |
| adservice / Java | SDK-disabled wins; master switch else legacy accepts `true` or `1`. Explicit gRPC exporters read per-signal endpoints before general endpoint, default `http://localhost:4317`. Legacy collector helper exists but is not used by exporter construction; do not rely on it |
| cartservice / .NET | SDK-disabled wins; master switch next, else legacy `ENABLE_TRACING=1`. SDK config reads standard endpoint/protocol settings; no `COLLECTOR_SERVICE_ADDR` fallback |

For every runtime, exact string `OTEL_TRACES_EXPORTER=none` or
`OTEL_METRICS_EXPORTER=none` suppresses the respective exporter; other values do
not select arbitrary exporters. Set the master switch to `false` or
`OTEL_SDK_DISABLED=true` to disable both. Stdout application logs continue.
Root traces use a parent-based ratio, `OTEL_TRACES_SAMPLER_ARG=0.1` default; use a
valid finite number in [0,1]. Incoming sampling decisions are retained. Python
clamps out-of-range ratios while other implementations generally fall back; avoid
invalid values. Generic sampler-name settings do not replace the explicit samplers.
Metric interval is `OTEL_METRIC_EXPORT_INTERVAL=10000` ms, minimum 1000; use valid
integers because Python/Java numeric parsing can fail on malformed values.

All eleven fix service.name to their component ID and namespace to `online-shop`.
`ONLINE_SHOP_VERSION` defaults to the image's full source SHA from the contract
build, or `development` outside images. `ONLINE_SHOP_ENVIRONMENT` defaults to
`local`. Go/Node/Python/Java use `HOSTNAME` with component fallback for instance;
.NET uses its ResourceBuilder default instance identity. These explicit resource
fields take precedence over generic service-name settings. Supply nonsensitive,
stable version/environment values.

All eleven implement manual traces, bounded transport/business metrics and
correlated JSON stdout records. Cart retains native ASP.NET SERVER Activities;
other services own manual transport spans. Loadgenerator produces CLIENT spans.
Health/reflection, baggage and unimplemented backend details are documented gaps.
There is no application SDK log exporter: SRE must collect/parse stdout and map
timestamp, severity, resource and trace/span IDs itself. The validation filelog
pipeline is an example, not an application dependency.

Exporters use short timeouts and bounded trace batches; loss on unavailable
export is intentional. Shutdown drains/flushed providers within container grace
periods; allow at least the historically validated 20-second aggregate budget.
Queues, retries and exact flush behavior differ by SDK. See the historical
[five-phase acceptance](../validation/otel/RESULTS.md) for disabled/refused/stalled
export and normal shutdown results, not a new runtime run for issue #25.

## External Redis and validation-only resources

Redis selection remains `docker.io/dmitryzhuravlev/online-shop-redis-cart` at
linux/amd64 manifest digest
`sha256:81be8a1f52db5f99fe3de0bbbd2efce827f51ce409155a95e9bdbac8c2721ba6`.
Use [redis.runtime.json](../redis.runtime.json) and [REDIS.md](REDIS.md) for tested
config identity, memory-only persistence, security, collection and cleanup.
Publisher lineage is unresolved. A fresh mirror, release review and explicit
Container/SRE downstream adoption remain required; this issue publishes or
replaces nothing.

Fault proxies, synthetic optional endpoints, probe/generated-client containers,
Redis setup helper, Collector JSON/file exporters, full sampling, short test
intervals and failure-phase overrides belong to the validation harness. They
are not additional application dependencies or CI source-build inputs.


## Kubernetes profile

[kubernetes/online-shop.yaml](../kubernetes/online-shop.yaml) contains 12 Deployments, 11 ClusterIP Services and 11 upstream ServiceAccounts. It preserves upstream selectors, internal DNS names, ports, probes, resource bounds, non-root container security and Redis `emptyDir` storage. It is a portable AML profile with the same component/image membership as `sre-dev-online-shop-v1`, **not a copy of the SRE chart or a claim of configuration/runtime equivalence**. In particular, frontend is a Deployment here; the SRE frontend Rollout belongs to SRE infrastructure.

Adaptations:

- Pin all 12 images to baseline digests and constrain scheduling to `linux/amd64`.
- Remove the upstream load-generator BusyBox init container, which is absent from the selected SRE baseline. There is no replacement image or startup gate; initial load-generator requests may fail until frontend becomes ready.
- Remove `frontend-external` LoadBalancer to avoid automatic external exposure and cloud cost. Frontend remains reachable internally through `frontend:80`.
- Remove Istio-specific probe annotations, disable service-account token automounting, set frontend platform to `local`, and explicitly disable its optional assistant while setting its required address to the disabled loopback sentinel `127.0.0.1:1`. The upstream frontend requires this address even with the feature disabled. Its flag hides the assistant UI; direct assistant API requests remain unsupported and fail against the sentinel. Existing profiler-disabling settings remain.
- Include no SRE infrastructure, failure-injection workload, assistant service, cloud provisioning, environment credentials, ConfigMaps or secret dependencies.

Redis carts are ephemeral and reset with the Pod's storage. Load generation is enabled at the upstream defaults of 10 users and rate 1, so this profile consumes resources and sends synthetic checkout traffic whenever started. Browser assets retain upstream public CDN/font URLs. Optional backend/cloud code remains in imported sources but is not selected by this profile. No deployment was performed; production exposure, persistence, policy, sizing and runtime compatibility require separate review.

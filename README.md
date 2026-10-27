# Application Modernization Lab

Application Modernization Lab maintains **Online Shop**, a polyglot microservices workload with manual OpenTelemetry instrumentation, explicit build inputs and portable runtime requirements. The canonical application lives in [`workloads/online-shop/`](workloads/online-shop/README.md), separate from the historical modernization experiments.

## Application and telemetry

The workload contains ten application services and a synthetic load generator:

| Component | Runtime | Responsibility |
|---|---|---|
| frontend | Go | Storefront HTTP entry point |
| checkoutservice | Go | Checkout orchestration |
| productcatalogservice | Go | Product catalog |
| shippingservice | Go | Shipping quotes and simulated shipping |
| cartservice | .NET | Shopping carts backed by Redis |
| currencyservice | Node.js | Currency conversion |
| paymentservice | Node.js | Simulated payment processing |
| emailservice | Python | Dummy email confirmation |
| recommendationservice | Python | Product recommendations |
| adservice | Java | Advertisements |
| loadgenerator | Python / Locust | Synthetic shopping traffic |

Redis is an **external runtime dependency**, with no local application source or Dockerfile. The accepted profile uses a standalone ephemeral cache: both Redis process restart and storage replacement lose carts. Image selection and runtime requirements remain in [images.lock.json](workloads/online-shop/images.lock.json) and [redis.runtime.json](workloads/online-shop/redis.runtime.json).

All eleven source components explicitly initialize OpenTelemetry. Manual transport and business spans provide distributed tracing with W3C context propagation; bounded request/error counters and duration histograms support metrics; JSON stdout logs carry service identity and active trace/span IDs. Cartservice retains the native ASP.NET SERVER Activity and enriches it manually. SDK trace/metric export is opt-in. Log collection and telemetry backends belong to the consuming platform. Redis server metrics and native logs are separate infrastructure signals, without Redis SERVER spans or trace-correlated server logs.

## Build inputs and runtime requirements

The [source-to-build handoff](workloads/online-shop/docs/BUILDING.md) defines eleven explicit build contexts, Dockerfiles, generated/shared inputs and a versioned consumer interface. [build.contract.json](workloads/online-shop/build.contract.json) and [build_plan.py](workloads/online-shop/build_plan.py) describe selected-revision plans; the planner does not build or publish images. External base images, package repositories and incomplete transitive locking prevent a promise of byte-identical builds.

The [runtime handoff](workloads/online-shop/docs/RUNTIME.md) specifies service endpoints, configuration, telemetry differences and the portable Kubernetes profile. The profile uses digest-pinned linux/amd64 images and internal Services; it includes no deployment or telemetry infrastructure. Production exposure, persistence, policy and sizing require downstream review.

**Instrumented sources and historical published images are distinct.** Existing Docker Hub images are copies of upstream artifacts, not builds of these adapted sources; they do not establish that local branding or manual instrumentation is deployed. Local source-build acceptance is separate evidence. New publication, image-reference adoption and cross-project integration remain downstream work. Historical provenance gaps and Redis publisher lineage remain unresolved; no release approval is implied.

## Documentation and validation

| Document | Scope |
|---|---|
| [Build inputs](workloads/online-shop/docs/BUILDING.md) | Consumer interface, dependency limits and regeneration matrix |
| [Runtime requirements](workloads/online-shop/docs/RUNTIME.md) | Endpoints, settings, runtime differences and Kubernetes profile |
| [Manual OpenTelemetry](workloads/online-shop/docs/TELEMETRY.md) | Traces, metrics, correlated logs, privacy and lifecycle |
| [Redis](workloads/online-shop/docs/REDIS.md) | Ephemeral cache, security, server collection and downstream handoff |
| [Upstream and image origins](workloads/online-shop/docs/UPSTREAM.md) | Import record, attribution and historical image provenance |
| [Static validation](workloads/online-shop/docs/VALIDATION.md) | Original import checks and their limits |
| [Build acceptance results](workloads/online-shop/validation/build/RESULTS.md) | Recorded clean-source builds of all eleven components |
| [Telemetry validation instructions](workloads/online-shop/validation/otel/README.md) / [results](workloads/online-shop/validation/otel/RESULTS.md) | Isolated source-build harness and recorded signal/lifecycle checks |
| [Redis acceptance results](workloads/online-shop/validation/otel/REDIS-RESULTS.md) | Recorded cache, outage/recovery, storage and collection checks |

Results describe their recorded revisions and execution conditions, not a new validation run or deployment. Frozen evidence retains historical document paths. Bare `BUILDING.md` references in the unchanged machine contract refer to the [document now under docs/](workloads/online-shop/docs/BUILDING.md).

## Platform responsibilities

| Repository | Responsibility |
|---|---|
| [Application Modernization Lab](https://github.com/DimitryZH/application-modernization-lab) | Application sources, instrumentation and build/runtime contracts |
| [CI Build Platform](https://github.com/DimitryZH/ci-build-platform) | Build execution and image publication with actual revision/run evidence |
| [Container Platform](https://github.com/DimitryZH/container-platform) | Release composition, artifact validation and eligibility review |
| [SRE Platform](https://github.com/DimitryZH/sre-platform) | Deployment and telemetry infrastructure |

These are ownership boundaries and handoff requirements. Planned integration and downstream adoption are not completed by AML's local acceptance. Detailed image records and follow-ups remain in the [upstream record](workloads/online-shop/docs/UPSTREAM.md#sources-images-and-future-builds) and [Redis handoff](workloads/online-shop/docs/REDIS.md#downstream-handoff).

## Modernization experiments

The separate [modernization experiments](experiments/README.md) preserve Docker Compose to .NET Aspire migrations, results and historical AI/agent-orchestration research.

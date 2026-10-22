# Issue #21 implementation evidence

Validation date: 2026-10-22. Environment: Windows host, Docker Linux/amd64, isolated local Compose projects. All application images were built from this repository; none were published.

## Initial implementation checks (before PR review)

The machine-readable [initial evidence summary](evidence-summary-initial.json) records source fingerprints, all eleven image IDs, unit results, acceptance results and cleanup. Raw evidence remains in ignored `output/<project>/` directories; it is not committed or represented as a remotely reproducible attestation.

- All eleven real application Dockerfiles built successfully. Cartservice used the unchanged fully trimmed, self-contained, single-file publish options and chiseled runtime, then served real Redis-backed requests.
- Thirteen unit/SDK commands passed: four Go module suites, two Node suites and two enabled SDK startup/shutdown checks, three Python suites, .NET's five tests, and Java's interceptor test/build. Python includes the load-generator POST-data regression; frontend includes unknown-method label bounding.
- Full acceptance passed twice on the final application source: `online-shop-21-4135affc` exported 2,357 spans and 2,624 correlated log records; `online-shop-21-caacb376` exported 2,270 spans and 2,520 correlated log records. Both covered all eleven services in traces, metrics and correlated logs. Counts vary with load scheduling.
- All fifteen business RPCs had SERVER coverage. Direct RPC assertions required exactly one SERVER span; checkout required downstream SERVER parents to be exported CLIENT spans. Cartservice's native SERVER Activity and manual business/cache children were present.
- Browsing, product view, cart quantity, checkout confirmation and cart clearing passed. Payment/shipping failures retained the cart; tolerated email/cart-clear failures retained successful checkout and emitted degradation events. Ad timeout, recommendation fallback, product-not-found, payment rejections and deadline scenarios passed.
- Twenty simultaneous requests preserved distinct parents. Load-generator CLIENT spans had no leaked parents. Unsampled incoming parents produced no recorded spans. Optional packaging/assistant HTTP propagation passed using a local fixture.
- Metric attribute allowlists and histogram boundaries passed. Correlated LogRecord IDs resolved to actual spans with matching service resources. Raw logs and exported signals contained none of the synthetic privacy canaries.

The complete five-phase run `online-shop-21-caacb376` passed: full, disabled, stalled Collector, refused Collector and Redis failure. Disabled/unreachable export phases retained successful shopping and produced no exported traces or metrics, including shutdown. Redis failure returned the expected bounded RPC failure. Application shutdowns exited normally (0 or 143), without forced kills, within the asserted 20-second aggregate bound. Cleanup exited 0 with no remaining project containers. The final-source fingerprint is `318cd6c035c680c7845502298ef0f8b21203eae0-dirty.641b7f99fbec`; the dirty suffix reflects pending validation/documentation work. Subsequent validation/documentation commits do not change application build inputs.

## Failures found and corrected

Early iterations were not successful acceptance runs. Runtime validation caught a Node metric interval/timeout incompatibility, a missing ASP.NET Activity source subscription, incorrect load-generator positional POST arguments, and Collector log resources shared across service batches. Fixes were tested with freshly built application images or corrected Collector configuration. Node exporter shutdown now tolerates a refused endpoint without failing normal process exit.

The harness also needed corrections for a shadowed Python concurrency module, profile-aware cleanup, and a Redis-failure test that incorrectly required a healthy storefront after Redis was stopped. Run `online-shop-21-4135affc` passed full/disabled/stalled/refused phases but its Redis phase timed out on that readiness bug; it is not claimed as an overall successful run. The final run uses the corrected direct Redis-failure probe.

## Review and limits

Self-review checked explicit transport ownership, scope restoration, bounded attributes, safe diagnostic logging, handled failure semantics, Docker build inputs, shutdown and cleanup. Git whitespace checks passed. Changes stay under `workloads/online-shop`; shared protocols, historical image locks and the canonical Kubernetes manifest are unchanged. The instrumentation contract documents dependency and design refinements.

Unexecuted: live optional cloud catalog/Spanner/AlloyDB backends, Kubernetes deployment, image publication, external integration, browser visual checks, production-scale load and a comprehensive dependency/security audit. Native profiler compatibility required retaining Node 20.17.0; inherited dependency advisories remain outside this instrumentation change. Existing optional-backend trim warnings remain, with no relaxation of cartservice packaging. Demo payment, shipping and email remain simulated.

No Aspire migration is performed by this issue. The local Compose topology adds only validation infrastructure: Collector, a failure/HTTP fixture and a probe. These are not changes to another project's deployment or integration.


## PR #22 review corrections

The original runs above do **not** validate these subsequent fixes. New acceptance checks compare actual RED counter values and matching attribute sets, histogram observation counts, and native OTLP LogRecord timestamp/severity fields. In-memory SDK tests compare failed-operation span status, metric deltas and completion logs, including correlation.

- Frontend/load-generator HTTP clients consistently classify `http_4xx`, `http_5xx` and `transport_error`. Server 4xx remains an expected rejection; server 5xx fails. Response/error return behavior is preserved. Python RPCs returning a non-OK context status without raising also count as failures.
- All transport request/error/duration series carry identical `operation`, `kind`, `outcome` attributes. Go adds missing error outcome; Node/Java add missing kind and outcome. Server/client/internal remain distinct.
- Diagnostics preserve severity, allowlisted category/event, bounded error classification and context. Explicit startup/configuration/dependency categories replace ambiguous records. Raw messages/exception details remain suppressed. Collector maps timestamp, severity number/text and trace/span IDs into native LogRecord fields.
- Cartservice's release Dockerfile and package/publish configuration are unchanged by these corrections.

The final unit/SDK run (`output/review-unit-final`) passed all 13 commands: four Go module suites; two Node suites (four tests each) plus two enabled startup/shutdown checks; Python suites (4 email, 4 recommendation, 6 load-generator tests); .NET (6 tests); Java (2 tests/build). HTTP tests exercise 503/404, returned status 0, raised transport failure and successful responses using real SDK readers/exporters. Nonexception RPC status accounting is covered in all three Python copies; Node and Java tests check exact error/request counts and identical labels.

Final source images identify `469621fd011626f6ce1e7269034aee525d4fb183-dirty.365c21c43d8a`. The dirty marker reflects pending harness/documentation changes, and no later commit changes application build inputs. Final full telemetry assertions passed on `online-shop-21-7c2cc4e2`: 2,573 spans and 3,181 correlated logs across all eleven services, all fifteen RPCs, exact RED series/count agreement, timestamp/severity number/text mapping, privacy canaries, parentage, concurrency and tolerated failures. The severity-text assertion was additionally rerun directly against the completed full-phase evidence.

The final complete run **passed all five phases**: full, disabled, stalled Collector, refused Collector and Redis failure. Shopping remained functional when export was disabled/unreachable; no traces/metrics were exported in those phases. Shutdown exits were normal, within the 20-second bound, and cleanup exited 0 with no remaining containers. See the current [review-fix evidence summary](evidence-summary.json) for image IDs, source identity, unit outcomes and shutdown times. Self-review and Git whitespace checks passed; changes remain within this workload. An interim revised-image run (`online-shop-21-d8233277`) passed all five phases, with 2,228 spans and 2,508 correlated logs, including strengthened RED and LogRecord assertions. Later Go context and Java diagnostic refinements belong to the final run, not that interim result.

During iteration, the Python regression initially constructed its SDK reader under `OTEL_SDK_DISABLED=true`; the isolated test now enables its in-memory SDK. A mechanical Go context edit accidentally changed catalog identifiers; compilation caught it and the identifiers were restored. Both failures were corrected before the passing final unit set. No remaining failed check is being treated as passed.

All original unexecuted-environment and dependency limitations above still apply. No publication, deployment, changes to another repository, merge, or issue closure is part of these corrections.

# Trail Supply validation boundaries

[Foundation results](../validation/FOUNDATION-RESULTS.md) preserves the earlier static
checks. [Storefront results](../validation/STOREFRONT-RESULTS.md) and its compact
machine-readable summary record the actual subsequent source-build, telemetry
and browser scope. Historical Online Shop evidence is linked in [UPSTREAM.md](UPSTREAM.md),
not copied or asserted as independent Trail Supply acceptance.

## Storefront checks

`python -B workloads/trail-supply/validation/storefront_test.py` checks approved
IDs/prices/Money, advertisement/category references, local assets/hashes and the
build asset inventory. Frontend Go tests execute every complete template with
empty and prefixed BASE_URL, real handler-shaped data, empty cart and favicon
override states.

## Static checks (no container engine)

From the repository root, with Python 3.10+, Git and the Docker Compose v2 CLI:

```powershell
git diff --check
python -B workloads/trail-supply/validation/build/test_build_plan.py
python -B workloads/trail-supply/validation/otel/test_redis_contract.py
python -B workloads/trail-supply/local/test_compose.py
$revision = (git rev-parse HEAD).Trim()
python -B workloads/trail-supply/build_plan.py --revision $revision --components adservice cartservice checkoutservice currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice shippingservice
```

Compose configuration rendering does not start Docker Desktop or contact a
container engine. Planner tests create a disposable Git repository containing
only Trail Supply; negative path/contract/COPY/ARG/platform guards remain active.
The planner reads committed Git objects, not unstaged edits or untracked files.

## Runtime reproduction (requires a running Linux engine)

- `python workloads/trail-supply/validation/build/verify.py`: all eleven source
  builds from a clean LF checkout; rejects undeclared context artifacts and
  mismatched checkout bytes. Never publishes.
- `python workloads/trail-supply/validation/otel/run.py`: five-phase application
  telemetry acceptance, real cart/Redis and fault cases; project-scoped cleanup.
  `--only full` is a focused shopping/telemetry check, not all-phase acceptance.
- `python workloads/trail-supply/validation/otel/run_redis.py`: focused Redis
  security, behavior, outage/recovery, metrics/logs and cleanup acceptance.
- `python workloads/trail-supply/validation/otel/unit.py`: inherited service tests,
  with the recommendation deadline suite included. Uses containers/builds.
- [Local review commands](../local/README.md): persistent browser session without
  fault injection or synthetic load by default. Separate from measured acceptance.

Use a fresh committed revision and an isolated checkout with
`core.autocrlf=false` for strict build acceptance. Runtime outputs go to ignored
`validation/*/output`; they must identify their actual revision and scope.
A successful static check does not demonstrate build success, pullability,
checkout correctness, browser behavior, telemetry delivery or deployment.

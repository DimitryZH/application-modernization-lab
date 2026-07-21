# Online Boutique Aspire Validation Results

Date: 2026-07-20
Environment: Ubuntu 24.04 DevBox, .NET SDK 10.0.110, Docker 29.6.1, Aspire AppHost SDK 13.4.6.

## Build

Command:

```bash
dotnet build experiments/06-online-boutique/02-compose-to-aspire/OnlineBoutique.Aspire.sln
```

Result: PASS. The AppHost built with 0 warnings and 0 errors.

## Aspire Runtime Validation

Command:

```bash
dotnet run --project experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj --no-build
```

Observed dashboard: Aspire printed a local HTTPS dashboard URL and login URL.

Frontend health:

```bash
curl -fsS http://localhost:8080/_healthz
```

Result: PASS, returned `ok`.

Host exposure check:

```bash
docker ps --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
```

Result: PASS. Only the `frontend` container had a loopback host mapping. Backend services and Redis exposed only container ports.

Functional workflow:

```bash
# One cookie jar was used for all requests.
GET  /
GET  /product/OLJCESPC7Z
POST /cart product_id=OLJCESPC7Z quantity=1
POST /cart/checkout with the known validation checkout payload
```

Result: PASS.

Evidence:

- Home page contained `Sunglasses`.
- Product page contained `Add To Cart`.
- Cart page after add-to-cart contained `Sunglasses`.
- Checkout response contained `Your order is complete`.

Stability and environment check:

Result: PASS after a 30 second stability window.

Required resources were running, not restarting, restart count `0`, and exit code `0`:

- `redis-cart`
- `adservice`
- `cartservice`
- `checkoutservice`
- `currencyservice`
- `emailservice`
- `frontend`
- `paymentservice`
- `productcatalogservice`
- `recommendationservice`
- `shippingservice`

Critical environment mappings verified in running containers:

- `frontend`: `PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550`
- `frontend`: `CART_SERVICE_ADDR=cartservice:7070`
- `frontend`: `CHECKOUT_SERVICE_ADDR=checkoutservice:5050`
- `frontend`: `AD_SERVICE_ADDR=adservice:9555`
- `frontend`: `SHOPPING_ASSISTANT_SERVICE_ADDR=shoppingassistantservice:80`
- `frontend`: `ENABLE_PROFILER=0`
- `checkoutservice`: `EMAIL_SERVICE_ADDR=emailservice:8080`
- `checkoutservice`: `CART_SERVICE_ADDR=cartservice:7070`
- `checkoutservice`: `CURRENCY_SERVICE_ADDR=currencyservice:7000`
- `cartservice`: `REDIS_ADDR=redis-cart:6379`

## Optional Load Generator Smoke Test

Command:

```bash
dotnet run --project experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj --no-build -- --OnlineBoutique:EnableLoadGenerator=true
```

Result: PASS. A `loadgenerator` container started only when the opt-in setting was supplied.

## Compose Baseline Comparison Check

Command:

```bash
docker compose -p online-boutique-exp06 -f experiments/06-online-boutique/01-kubernetes-to-compose/compose.yaml config --quiet
docker compose -p online-boutique-exp06 -f experiments/06-online-boutique/01-kubernetes-to-compose/compose.yaml up -d
```

The same shell health, browse, product detail, cart, checkout, and 30 second stability checks were run against `http://localhost:8080`.

Result: PASS. All required Compose services were running, not restarting, restart count `0`, and exit code `0`. The stack was cleaned up with:

```bash
docker compose -p online-boutique-exp06 -f experiments/06-online-boutique/01-kubernetes-to-compose/compose.yaml down -v --remove-orphans
```

## Notes

The repository validator is provided as `scripts/validate-aspire.ps1`, matching the Compose validator style. For the original 2026-07-20 evidence, it was syntax-reviewed and the equivalent validation logic was executed with shell commands because `pwsh` was not available in that environment at the time.

## Validator Correction Evidence

Date: 2026-07-21
Environment update: PowerShell 7 was available at `/home/devclaw-svc/.local/bin/pwsh`.

The Aspire validator was corrected to select containers by Aspire/DCP-managed resource identity before checking image digests, state, and environment. The selected containers must have:

- `com.microsoft.developer.usvc-dev.group-version=usvc-dev.developer.microsoft.com/v1`;
- `com.microsoft.developer.usvc-dev.name` matching the expected AppHost resource name plus DCP suffix, such as `frontend-pgmrsjpd`;
- a shared DCP creator process identity across all required resources.

Actual Aspire validation commands:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/06-online-boutique/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj -StableSeconds 5
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/06-online-boutique/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj -StartAppHost -StableSeconds 5
```

Result: PASS. The validator built the AppHost, checked frontend health, completed browse/cart/checkout/order workflow, verified required container stability, printed image inventory entries with Aspire/DCP labels, and passed in self-starting cleanup mode. The self-starting run reported labels such as `frontend-mystpdeq`.

Concurrent Compose proof:

```bash
perl -pe 's/127\.0\.0\.1:8080:8080/127.0.0.1:18080:8080/' experiments/06-online-boutique/01-kubernetes-to-compose/compose.yaml >/tmp/online-boutique-compose-concurrent.yaml
docker compose -p online-boutique-exp06-concurrent -f /tmp/online-boutique-compose-concurrent.yaml up -d
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/06-online-boutique/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj -StableSeconds 5
```

Result: PASS while Aspire and Compose baseline containers were running concurrently. The validator inventory reported Aspire/DCP labels for every selected resource, proving same-image Compose containers were ignored.

Compose-only negative proof:

After stopping the Aspire AppHost and leaving the temporary Compose baseline running on `http://localhost:18080`, this command was run:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/06-online-boutique/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/06-online-boutique/02-compose-to-aspire/src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj -BaseUrl http://localhost:18080 -StableSeconds 1
```

Result: EXPECTED FAIL. The Compose frontend health and shopping workflow succeeded, but the validator failed at the Aspire container assertion with `missing running Aspire-managed container for frontend`. This proves concurrent Docker Compose containers using the same pinned images cannot satisfy Aspire validation.

Cleanup:

```bash
docker compose -p online-boutique-exp06-concurrent -f /tmp/online-boutique-compose-concurrent.yaml down -v --remove-orphans
```

Result: PASS. No Online Boutique containers remained running after cleanup.

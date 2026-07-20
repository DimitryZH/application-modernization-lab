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

The repository validator is provided as `scripts/validate-aspire.ps1`, matching the Compose validator style. It was syntax-reviewed and the equivalent validation logic was executed with shell commands in this environment because `pwsh` is not installed on the DevBox.
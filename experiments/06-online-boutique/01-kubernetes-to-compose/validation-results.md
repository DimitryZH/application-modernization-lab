# Docker Compose Baseline Validation

Date: 2026-07-20

## Environment

- Host: Windows with Docker Desktop
- Compose command used for validation: `docker-compose` v2.40.2
- Note: this workstation exposes Compose as `docker-compose.exe`; the Compose plugin form `docker compose` was not available here.

## Commands

```powershell
docker-compose -p online-boutique-exp06 config --quiet
powershell -ExecutionPolicy Bypass -File .\scripts\validate-compose.ps1
```

## Result

PASS

The validator completed:

- Compose configuration check;
- required image pull;
- optional `loadgenerator` image pull;
- required stack startup;
- frontend availability check at `http://localhost:8080/_healthz`;
- browse, cart, and checkout path;
- 30 second required-container stability window;
- resolved image inventory output;
- repeatable shutdown with `down -v --remove-orphans`.

## Functional Evidence

The validation used a single browser session and completed this path:

1. `GET /` returned the product listing and included `Sunglasses`.
2. `GET /product/OLJCESPC7Z` returned the product page and included `Add To Cart`.
3. `POST /cart` with `product_id=OLJCESPC7Z` and `quantity=1` returned the cart page and included `Sunglasses`.
4. `POST /cart/checkout` with test customer, address, and card fields returned an order page containing `Your order is complete`.

This path exercises frontend-to-product-catalog, frontend-to-currency, frontend-to-cart, cart-to-Redis, frontend-to-shipping, frontend-to-checkout, checkout-to-cart, checkout-to-payment, checkout-to-shipping, and checkout-to-email communication.

## Required Service Inventory

- `frontend`: host-published HTTP endpoint on `127.0.0.1:8080`.
- `adservice`: internal gRPC service on `9555`.
- `cartservice`: internal gRPC service on `7070`, backed by Redis.
- `checkoutservice`: internal gRPC service on `5050`.
- `currencyservice`: internal gRPC service on `7000`.
- `emailservice`: internal gRPC service on container port `8080`.
- `paymentservice`: internal gRPC service on `50051`.
- `productcatalogservice`: internal gRPC service on `3550`.
- `recommendationservice`: internal gRPC service on `8080`.
- `shippingservice`: internal gRPC service on `50051`.
- `redis-cart`: internal Redis service on `6379`.

Optional service:

- `loadgenerator`: available through the `loadgenerator` Compose profile; image pull validated, not required for the main checkout path.

## Image Pinning

All application images use the upstream `v0.10.6` release tag plus digest. Redis uses the digest-pinned upstream Helm image reference.

## Decisions and Limitations

- The baseline does not vendor application source code.
- The baseline keeps only `frontend` exposed to the host.
- `EMAIL_SERVICE_ADDR` uses `emailservice:8080` because Compose has no Kubernetes Service object to remap service port `5000` to target port `8080`.
- No application source files were modified.
- No .NET Aspire files were added.

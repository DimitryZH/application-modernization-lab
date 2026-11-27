# Trail Supply storefront — local validation

Date: 2026-11-27. Application source:
`10f570d1e5763ac789db86991abd77a097534375`.
[Machine-readable summary](storefront-evidence.json).
Owner visual acceptance is **pending**. This is local application evidence, not
SDP trusted build, signing, admission, release or deployment acceptance.

## Executed checks

| Check | Actual result |
|---|---|
| Build planner | 23 tests passed; committed workload plans checked |
| Catalog/ads/assets | 4 consistency tests passed; approved IDs/prices/Money, ad categories/routes, local asset hashes and inventory |
| Local Compose / Redis contracts | 6 review configuration tests and 6 inherited Redis checks passed |
| Frontend | Go compilation and unit suites passed, including real template rendering with handler-shaped data, prefixed routes, empty cart, alternate favicon and price-rounding regression |
| Product catalog | Existing Go unit suites passed |
| Recommendation | 10 telemetry/deadline tests passed in the locally built image with external network disabled; absent/short/expired caller deadlines retain the accepted behavior |
| Email | 4 telemetry tests and Jinja confirmation-template render passed |
| Advertisement service | Release Dockerfile ran 2 Java tests; no failures/errors/skips |
| Local source images | All ten application images built from source; all running image revision labels match the source above |
| Telemetry acceptance | `run.py --only full` passed in `trail-supply-validation-1db38118`; all eleven application/helper images built, strict existing signal/privacy assertions retained, scoped cleanup passed |
| Browser | Desktop 1440×1000 and mobile 390×844 inspected; nine product pages/images, recommendations, currency, quantity/cart, empty-cart action, simulated checkout, confirmation/cart clearing, invalid email behavior, missing-product error, navigation anchors and visible keyboard focus checked |
| BASE_URL | Separate `localhost:18082/trail/` project passed product/cart/checkout/confirmation/cart clear and homepage anchors; its containers/network/disposable volume were removed |

The full telemetry phase covers direct RPCs, payment/shipping/email/cart-clear
fault behavior, ad/recommendation fallbacks, deadlines, concurrency, sampling,
optional outbound HTTP propagation, metrics and correlated safe logs. Its source
label is `10f570d1e5763ac789db86991abd77a097534375.f5c453cfa281`.
The other four phases were not run in this stage. The earlier full run before
the display-rounding correction also passed but is not the final source record.

A real-browser check found the inherited formatter truncating conversion
remainders (for example 128.999999999 → 128.99). The frontend now rounds the
displayed amount to cents; backend money values, calculation and currency RPCs
are unchanged. Approved USD prices now display correctly.

## Browser artifacts and bounds

Five JPEG screenshots are retained locally under ignored
`local/output/screenshots/`: `desktop-home.jpg`, `mobile-home.jpg`,
`product-detail.jpg`, `cart-checkout.jpg`, `order-confirmation.jpg`.
They are not committed or uploaded. Raw builds, browser observations and telemetry
output also stay in ignored directories. No real customer/payment data was used.

No horizontal overflow was found on desktop/mobile or mobile checkout. Rendered
presentation asset URLs are local; source checks remove font/CDN dependencies.
The browser console contained no warnings/errors during the recorded journey.
No HAR capture was performed. All nine product-detail images loaded at 1254×1254;
selected JPEG output and the supplied image mapping were inspected visually.

## Running owner-review session

The session below records the original review cohort. The subsequent
[footer refinement](FOOTER-REFINEMENT.md) updates only the frontend image to
`8006950de7d5cb2f9d6dfce87fb569463b075a1b`; all other containers/images are
unchanged. Use that focused record for the current footer verification.

- URL: `http://127.0.0.1:18081/`.
- Project: `trail-supply-review-6a3e949e`.
- Ten application services plus Redis running; Redis healthy; ownership init
  completed with exit 0. Loadgenerator is absent. Backend ports are not published.
- SDK export disabled for manual browsing; telemetry acceptance used another
  isolated project. The review session remains running until owner cleanup.
- Source revision for all ten application images:
  `10f570d1e5763ac789db86991abd77a097534375`.

Cleanup destroys this review session's synthetic in-memory carts and volume.
From the repository root, when the owner is finished:

```powershell
docker compose -p trail-supply-review-6a3e949e -f workloads/trail-supply/local/compose.yaml down --volumes --remove-orphans
```

## Limitations and downstream handoff

The exact pinned Redis manifest was successfully pulled and exercised with config
ID `sha256:98c6ca8f397f86e469be752c3e7ed5eb8b17f2479840cb69a2e413037038e9f4`
on Linux/amd64. This local observation does not change its inherited canonical
publication/equality/attestation trust requirements. No replacement was selected.

Strict clean-LF `validation/build/verify.py`, the remaining telemetry phases,
focused Redis acceptance and production/cloud profiles were not run for this
storefront stage. The owner's checkout was not normalized or replaced.

SDP must select `workloads/trail-supply` and an immutable revision, build/admit new
artifacts independently and keep the existing service/protobuf/telemetry/runtime
identities. Historical image locks/Kubernetes references are not new Trail Supply
release artifacts. No downstream repository or cloud resource was changed.

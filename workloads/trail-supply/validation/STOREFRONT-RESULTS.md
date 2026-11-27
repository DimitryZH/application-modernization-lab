# Trail Supply storefront — acceptance and local validation

Date: 2026-11-27. Application source:
`10f570d1e5763ac789db86991abd77a097534375`.
[Historical machine-readable snapshot](storefront-evidence.json) records the
initial review cohort, including its then-pending owner status. The final
acceptance and cleanup below supersede those status fields without relabeling
historical builds or tests. This is local application evidence, not
SDP trusted build, signing, admission, release or deployment acceptance.

## Final owner acceptance and closure

On 2026-11-27 the owner explicitly accepted the storefront design, nine-product
catalog, functionality and final footer refinement. Application modernization is
complete and ready for owner merge authorization. No application-scope blocker
was found in the final review. PR #30 remains open in Draft and issue #29 remains
open; neither was merged or closed.

The final footer contains Trail Supply branding, internal navigation and the
existing demo disclaimer. The upstream-source paragraph and technical runtime
details are removed, including their unused styles. Copyright/Apache-2.0 source
headers, LICENSE and documented upstream attribution remain preserved.

| Evidence / source | Actual scope |
|---|---|
| `10f570d1e5763ac789db86991abd77a097534375` | Broad source builds, unit/static checks, full telemetry phase and desktop/mobile/prefixed browser journey recorded below |
| `8006950de7d5cb2f9d6dfce87fb569463b075a1b` | Historical intermediate footer text, focused template tests and frontend-only build/browser review |
| `c7ed4c4a867720598f5cfe1984b26eebdf3e55f0` | Final footer cleanup; focused template tests, frontend-only build/recreation and compact/desktop browser checks in [footer results](FOOTER-REFINEMENT.md#shopper-facing-footer-cleanup) |
| `a119501fd36f14d9c80a737d362c8782271a59b8` | Reviewed handoff snapshot containing the final application and previous validation docs; planner has eleven components / 198 input entries. All component input hashes match `c7ed4c4`; all ten non-frontend components also match `10f570d` |
| Final closure commit | Documentation and acceptance metadata only; no application/build input, dependency or runtime configuration changes |

Final diff review confirmed that only the repository overview and Trail Supply
differ from the accepted main baseline. Online Shop and experiments are unchanged.
All 20 shared/service protobuf and tracked generated-binding files match the
baseline, as do recommendation source/deadline tests, Dockerfiles and telemetry
implementation. The remaining source edits are frontend presentation/price
display, catalog data, ad data and the email template. Upstream copyright headers
in all 16 modified files that carried them remain. Runtime/service/telemetry
identities and licensing contracts are preserved.

Existing successful application evidence was reused. Closure checks were limited
to diff/protected-path and source/plan comparisons, documentation links, JSON and
Git whitespace checks, plus scoped cleanup verification. No build, browser
journey or comprehensive acceptance suite was repeated. The
[SDP adoption handoff](../docs/BUILDING.md#sdp-adoption-handoff) gives the workload,
revision-selection, changed-component and contract requirements.

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

## Closed owner-review session

The session below records the completed review cohort. The subsequent
[footer refinement](FOOTER-REFINEMENT.md) updated only frontend to
`c7ed4c4a867720598f5cfe1984b26eebdf3e55f0`; other application images remained
at `10f570d1e5763ac789db86991abd77a097534375`.

- Former URL: `http://127.0.0.1:18081/`; no longer serving after cleanup.
- Project: `trail-supply-review-6a3e949e`.
- Before cleanup: ten application services plus healthy Redis; ownership init
  exited 0. Loadgenerator was absent. Only frontend had a loopback published port.
- SDK export was disabled for manual browsing; telemetry acceptance used another
  isolated project.

After owner acceptance, executed from the repository root:

```powershell
docker compose -p trail-supply-review-6a3e949e -f workloads/trail-supply/local/compose.yaml down --volumes --remove-orphans
```

Cleanup removed all 12 dedicated containers, the project network and synthetic
Redis volume. Label-filtered checks found zero remaining project containers,
networks or volumes; the former URL no longer responds. Before/after inventories
confirmed all three unrelated containers retained IDs, image IDs and state, all
129 images remained, and all 31 unrelated volumes and 17 other networks remained.
No image removal, cache deletion or global prune was used. Raw cleanup/source-plan
comparison records remain ignored local artifacts under `local/output/`.

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

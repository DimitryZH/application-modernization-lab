# Footer branding refinement — focused validation

Date: 2026-11-27. Frontend source revision:
`8006950de7d5cb2f9d6dfce87fb569463b075a1b`.

The right-hand footer now reads **Trail Supply demo storefront · Upstream source**.
The existing upstream URL remains
`https://github.com/GoogleCloudPlatform/microservices-demo`.
Visible Google copyright/product-disclaimer text was removed from this
presentation paragraph. The original Google copyright and Apache-2.0 header in
the template, repository LICENSE, applicable notices and documented upstream
attribution are unchanged. The left demo disclaimer, branding/logo, runtime
details, CSS/layout/colors and responsive rules are unchanged.

## Executed checks

- Focused Go template tests passed in an isolated, network-disabled Go container:
  `go test . -run "TestStorefrontTemplates|TestEmptyCartAndLegacyFaviconSwitch" -count=1 -v`.
  This executes six complete page templates with empty and prefixed BASE_URL
  (12 cases), plus the empty-cart/alternate-favicon case.
- A source comparison confirmed exactly one presentation-line substitution in
  `footer.html`; the copyright/license header and all surrounding markup match.
- Rebuilt only `frontend`, then recreated only that service using
  `up -d --no-build --no-deps --force-recreate frontend` in the existing
  `trail-supply-review-6a3e949e` project.
- Compared container and image IDs before/after: only frontend changed; every
  other application service, Redis and the completed ownership helper retained
  its container/image identity. No unrelated service was rebuilt or recreated.
- HTTP 200 at `http://127.0.0.1:18081/`. Browser reloaded the new frontend and
  confirmed the exact visible footer text, preserved upstream href and disclaimer,
  functional runtime-details disclosure, desktop two-column layout and compact
  layout without horizontal overflow. Temporary viewport override was reset.
- Git whitespace/scope checks passed. The complete telemetry suite was not rerun
  for this cosmetic change. Prior broader validation remains a historical record.

The frontend local image ID is
`sha256:7e943749dabaed56da49f24129c11755e465dd01168530fe1a6469739e6cd12d`.
Its revision label matches the frontend source above. Other application images
remain at source `10f570d1e5763ac789db86991abd77a097534375`.
Local screenshots are ignored artifacts:
`local/output/screenshots/footer-refinement.jpg` and
`local/output/screenshots/footer-refinement-desktop.jpg`.

The application remains running for final owner review at
`http://127.0.0.1:18081/`. PR #30 stays Draft; issue #29 remains open.
No new owner visual acceptance or downstream release acceptance is claimed.

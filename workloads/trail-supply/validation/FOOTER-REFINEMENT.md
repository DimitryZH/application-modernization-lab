# Footer branding refinement — focused validation

The final owner-requested cleanup is recorded below under
[Shopper-facing footer cleanup](#shopper-facing-footer-cleanup). It supersedes
the initial visible footer state recorded here; the earlier checks remain historical.

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

## Shopper-facing footer cleanup

Date: 2026-11-27. Frontend source revision:
`c7ed4c4a867720598f5cfe1984b26eebdf3e55f0`.

Following owner review, removed the complete upstream-source paragraph and
runtime-details disclosure (session/request IDs, hostname and deployment details)
from the shared footer. Removed their unused CSS and the obsolete two-column
footer-bottom layout. Trail Supply branding/navigation, colors and the existing
demo disclaimer remain. Google copyright and Apache-2.0 source headers, LICENSE
and repository attribution remain intact. Backend data, logging and telemetry
were not changed.

- PASS: `go test . -run "TestStorefrontTemplates|TestEmptyCartAndLegacyFaviconSwitch" -count=1`
  in the existing disposable network-disabled Go validation container, using
  read-only source and existing Go cache volumes. The complete templates cover
  12 page/prefix cases plus the empty-cart/alternate-favicon case.
- PASS: rebuilt only frontend and recreated only its container in
  `trail-supply-review-6a3e949e` with `up -d --no-build --no-deps --force-recreate frontend`.
  Before/after container and image IDs confirm every other service, Redis and
  the completed ownership helper retained its identity.
- PASS: HTTP 200 at `http://127.0.0.1:18081/`; browser reload confirms the footer
  has only branding, internal navigation and the demo disclaimer. No external
  footer links or details disclosure remain. Compact (319px content width) and
  desktop (1425px content width) checks found no horizontal overflow. The
  temporary viewport override was reset.
- PASS: Git whitespace/scope checks; original Online Shop and experiments unchanged.
  The complete telemetry suite and unrelated builds were not rerun for this
  presentation-only change. Earlier broader evidence retains its original scope.

The frontend local image is
`sha256:f00557315af2595751f6d113eb07156619f6e9b5842406c6e971ee7c1107eb53`,
with revision label matching the source above. Other application images remain
at `10f570d1e5763ac789db86991abd77a097534375`. The local ignored screenshot is
`local/output/screenshots/footer-cleanup.jpg`.

The same review stack remains running for final owner review. PR #30 remains
Draft and issue #29 remains open. No final owner acceptance is claimed.

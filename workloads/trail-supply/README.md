# Trail Supply — Outdoor Equipment Store

A fictional outdoor storefront built on the existing Go HTML templates and
microservice architecture. **Gear up. Get outside.**

The storefront includes an editorial mountain hero, Hiking/Camping/Essentials
features, nine catalog products, a brand-story section, product details, cart,
simulated checkout, confirmation and error states. Currency conversion, product
IDs, service identities, `online-shop` telemetry namespace and runtime interfaces
are preserved. No new backend, database or frontend framework is introduced.

## Build, run and validate

- [Local review](local/README.md): source-built images, a unique Compose project,
  loopback storefront and explicit cleanup. The owner-review stack stays running.
- [Build contract](docs/BUILDING.md): eleven workload-local build contexts and the
  selected-revision planner; Redis remains external.
- [Runtime](docs/RUNTIME.md), [telemetry](docs/TELEMETRY.md), [Redis](docs/REDIS.md).
- [Assets](docs/ASSETS.md): owner-provided ChatGPT-generated graphics, exact mapping
  and delivery sizes; no external image/font/CDN dependency.
- [Validation](docs/VALIDATION.md): static, source-build and browser evidence
  boundaries. Owner visual acceptance remains pending until explicit review.

## Lineage and compatibility

The independent foundation is `9033f3e8e4ec94d2f13edfbad95b608b3cb4a069`, derived
from Online Shop at `67b6cd85ae01c698bbf86904d953d5145b7b5820` using tracked content.
[Source lineage](source-lineage.json) and [upstream attribution](docs/UPSTREAM.md)
preserve the original Apache-2.0 license, Google copyright/source notices and
historical evidence. Online Shop and historical experiments are unchanged.

The same nine IDs now identify outdoor products. Old persisted carts would resolve
to the new names, prices and imagery; use isolated new sessions/storage for review.
Payment, shipping and email are simulated; never enter real payment/customer data.
Assistant and packaging backends are not supplied or enabled for local review.

`images.lock.json` and `kubernetes/online-shop.yaml` retain inherited artifact
identities/provenance gaps; they are not newly published Trail Supply artifacts.
No SDP build trust, signing, admission, release or deployment is claimed.
Downstream consumers must select this workload and a new immutable source revision,
build/admit their own images and isolate the unchanged service identities.

# Trail Supply frontend

Go HTML templates and local CSS render the outdoor storefront, product details,
cart, simulated checkout, confirmation, errors and optional assistant UI. Product
and currency data come through the existing service interfaces.

Use the workload [build contract](../../docs/BUILDING.md) for source builds and
[local Compose instructions](../../local/README.md) for browser review. Dependencies
are managed by the existing `go.mod` and `go.sum`; no frontend package manager or
asset build step is required. Run `go test ./...` from this directory with the
matching Go toolchain, or use the workload's container validation path.

Go module/protocol names, runtime settings, cookies, service identities and the
`online-shop` telemetry namespace intentionally retain their upstream interfaces.
Graphical asset provenance is recorded in [ASSETS.md](../../docs/ASSETS.md).

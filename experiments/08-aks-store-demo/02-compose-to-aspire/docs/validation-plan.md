# Validation Plan

Developer validation uses the committed native scripts:

- `scripts/validate-aspire.sh --start-apphost`
- `scripts/validate-negative.sh`
- `scripts/cleanup-aspire.sh --full-reset`

Positive validation checks:

- repository/version preflight;
- Experiment 08A `upstream-source.sha256`;
- AppHost build;
- all nine required Aspire resources;
- one shared current AppHost creator identity;
- loopback-only `store-front` and `store-admin`;
- internal-only backend services;
- required environment values;
- health and product proxy readiness;
- unique current-run order submission;
- RabbitMQ `orders` queue;
- makeline and DocumentDB-backed order visibility;
- makeline restart persistence;
- cleanup and untracked local evidence.

Negative validation stops only the current-run Aspire RabbitMQ container, requires the native validation path to fail non-zero, restores RabbitMQ, restarts dependent services when needed, proves a fresh unique order reaches makeline/DocumentDB, and then cleans up.

Concurrent Compose isolation is covered by requiring Aspire/DCP labels and a shared creator identity. Compose containers using the same service names or images lack those labels and cannot satisfy validation.

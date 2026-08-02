# Validation Plan

Developer validation uses the committed native scripts:

- `scripts/validate-aspire.sh --start-apphost`
- `scripts/validate-negative.sh`
- `bash scripts/validate-cleanup-isolation.sh`
- `bash scripts/validate-ownership-guardrails.sh`
- `bash scripts/validate-failure-cleanup.sh`
- `scripts/cleanup-aspire.sh --full-reset`

Positive validation checks:

- repository/version preflight;
- Experiment 08A `upstream-source.sha256`;
- AppHost build;
- all nine required Aspire resources;
- one shared current AppHost creator identity;
- persisted AppHost PID, process start ticks, DCP creator process id/start-time, and all required resource identities before resource selection;
- loopback-only `store-front` and `store-admin`;
- internal-only backend services;
- required environment values;
- health and product proxy readiness;
- unique current-run order submission;
- RabbitMQ `orders` queue;
- makeline and DocumentDB-backed order visibility;
- makeline restart persistence;
- cleanup and untracked local evidence.

Negative validation starts a fresh Experiment 08B AppHost, verifies its persisted creator identity, stops only the current-run Aspire RabbitMQ container, requires the native validation path to fail non-zero, restores RabbitMQ, restarts dependent services when needed, proves a fresh unique order reaches makeline/DocumentDB, and then cleans up.

Cleanup isolation is validated by creating an unrelated DCP-labeled container with an overlapping resource label, cleaning up the current Experiment 08B AppHost identity, and proving the unrelated container is not removed or modified. Cleanup never selects the first globally matching Aspire/DCP container; it requires the persisted creator identity and the complete owned Experiment 08B resource set.

Ownership guardrails are validated by forcing missing, incomplete, stale, and partial unrelated DCP identity states. Cleanup must fail closed and leave unrelated resources intact.

Intentional failure cleanup is validated by forcing endpoint validation to fail, then proving diagnostic evidence remains while the owned AppHost and owned Experiment 08B containers are removed.

Concurrent Compose isolation is covered by requiring Aspire/DCP labels and a persisted shared creator identity. Compose containers using the same service names or images lack those labels and cannot satisfy validation.

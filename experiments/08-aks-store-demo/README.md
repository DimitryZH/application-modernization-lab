# Experiment 08: AKS Store Demo

Experiment 08 is the accepted AKS Store Demo modernization record. It preserves the official upstream source pinned to `Azure-Samples/aks-store-demo` commit `7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5` and records both the Docker Compose baseline and the .NET Aspire migration.

## Accepted Scope

- Experiment 08A: [`01-compose-baseline/`](01-compose-baseline/) contains the accepted Docker Compose baseline, source snapshot, validation scripts, runtime contract, and evidence.
- Experiment 08B: [`02-compose-to-aspire/`](02-compose-to-aspire/) contains the accepted .NET Aspire AppHost migration for the 08A baseline.
- Final retrospective: [`retrospective.md`](retrospective.md) separates the successful migration outcome from the orchestration-platform decision input.

## Final Outcome

Application-modernization result: Experiment 08B successfully migrated the accepted AKS Store Demo Docker Compose baseline to a reproducible .NET Aspire AppHost model. The migration remains technically valid and is retained as a completed Application Modernization Lab result.

Orchestration result: OpenClaw/DevClaw worker orchestration was evaluated during the historical experiment, but the evaluated architecture was not selected as the primary orchestration foundation for the AI Operations Platform. This does not reject OpenClaw or DevClaw in all roles, and it does not invalidate the Experiment 08B Aspire migration. OpenClaw may remain an optional communication gateway or interactive runtime subject to separate validation.

## Evidence Boundary

Experiment 08 does not claim durable DocumentDB persistence across recreation or full reset. It does not claim managed OpenClaw service restart persistence, VM reboot persistence, direct Codex and worker environment parity, or measured time, token, dollar-cost, operator-hour, or recovery-hour comparisons.

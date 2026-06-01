# Compose-to-Aspire Migration Research

This repository contains controlled Docker Compose to .NET Aspire migration experiments and the validation evidence collected from each run.

## Experiments

### Experiment 01 - Controlled Demo

Local Node.js, PostgreSQL, Redis, and .NET Aspire controlled demo used to validate end-to-end migration behavior. See [experiments/01-controlled-demo](experiments/01-controlled-demo/README.md).

### Experiment 02 - Browser Codex

Docker Example Voting App migration attempted from a browser-constrained agent environment. Result: 6/10. See [experiments/02-open-source-voting-app](experiments/02-open-source-voting-app/README.md).

### Experiment 03 - Codex Desktop

Docker Example Voting App migration performed from Codex Desktop with fuller local execution capability. Result: 8/10. See [experiments/03-codex-desktop-voting-app](experiments/03-codex-desktop-voting-app/README.md).

## Key Findings

- Browser agents are limited by execution environment.
- Desktop agents can complete full migration workflows.
- Observability requires application instrumentation.

## Repository Structure

```text
.
|-- AGENTS.md
|-- experiments/
|   |-- 01-controlled-demo/
|   |-- 02-open-source-voting-app/
|   `-- 03-codex-desktop-voting-app/
|-- LICENSE
`-- README.md
```

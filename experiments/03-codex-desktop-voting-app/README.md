# Codex Desktop Voting App Migration Experiment

This experiment validates a Docker Compose to .NET Aspire migration for Docker's Example Voting App.

## Layout

- `source/`: imported upstream Docker Example Voting App source.
- `aspire/`: .NET Aspire migration implementation.
- `tests/`: smoke tests used against both the Compose and Aspire deployments.
- `AI/`: execution reports, design notes, validation evidence, and final assessment.

## Source

- Repository: https://github.com/dockersamples/example-voting-app.git
- Commit: `63e9150ca17af4ed05880d4245e486481f73fcb4`
- Retrieved: 2026-06-01

## Validation Scope

The same smoke workflow is used for both deployments:

- Verify vote endpoint availability.
- Verify result endpoint availability.
- Submit a vote.
- Verify the result endpoint remains readable after worker processing.
- For Compose runs, verify all expected Compose services are running.

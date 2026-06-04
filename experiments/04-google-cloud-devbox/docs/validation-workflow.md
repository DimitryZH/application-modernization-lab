# Future Validation Workflow

This document describes the intended future workflow for running Docker Compose to .NET Aspire migration validation on the Google Cloud DevBox.

No migration implementation is included in Experiment 04.

## Workflow

1. Prepare the DevBox.
2. Clone the repository.
3. Validate prerequisites.
4. Run Docker Compose baseline.
5. Run Aspire build.
6. Run Aspire runtime.
7. Run smoke tests.
8. Collect evidence.
9. Produce a report.

## 1. Prepare the DevBox

Create or start the VM and connect through SSH:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/connect-devbox.sh
```

Install required tools if they are not already present.

## 2. Clone the repository

Clone the repository under the normal non-root VM user:

```bash
git clone <repository-url> compose-to-aspire-demo
cd compose-to-aspire-demo
```

## 3. Validate prerequisites

Run:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/check-devbox-prereqs.sh
```

Resolve any `FAIL` results before attempting migration validation.

## 4. Run Docker Compose baseline

For the selected experiment, run the original Compose stack and smoke tests before making migration changes.

The exact commands depend on the experiment. The validation should capture:

- Compose startup result;
- smoke test result;
- container status;
- relevant logs;
- cleanup command used.

## 5. Run Aspire build

Build the Aspire solution or AppHost project:

```bash
dotnet build
```

Use the selected experiment's documented build path.

## 6. Run Aspire runtime

Start the Aspire AppHost:

```bash
dotnet run --project <path-to-AppHost.csproj>
```

Keep logs available for evidence collection.

## 7. Run smoke tests

Run the same smoke tests used for the Compose baseline. If the Aspire version uses different local ports, update only the endpoint configuration and preserve the behavioral coverage.

## 8. Collect evidence

Run:

```bash
cd experiments/04-google-cloud-devbox
bash ./scripts/collect-devbox-evidence.sh
```

Use `VALIDATION_LOG_DIR` when validation logs are stored outside the default report directory:

```bash
VALIDATION_LOG_DIR=/path/to/logs bash ./scripts/collect-devbox-evidence.sh
```

## 9. Produce a report

The final report for a future migration should include:

- Compose baseline result;
- Aspire build result;
- Aspire runtime result;
- smoke test result;
- known differences;
- evidence file paths;
- manual follow-up items.

Functional equivalence should not be claimed unless the Compose and Aspire smoke tests pass.

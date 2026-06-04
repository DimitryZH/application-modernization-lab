# Scoring Model

## Purpose

This scoring model provides a consistent way to evaluate future Experiment 04 remote migration runs.

The score measures migration execution quality and validation evidence. It does not treat missing upstream telemetry as an automatic migration failure.

## Categories

| Category | Weight |
| --- | ---: |
| Compose Validation | 20 |
| Migration Quality | 20 |
| Aspire Build | 15 |
| Aspire Runtime | 20 |
| Functional Equivalence | 15 |
| Dashboard Validation | 10 |
| Total | 100 |

## Score bands

| Score | Result |
| --- | --- |
| 90-100 | PASS |
| 70-89 | PARTIAL_PASS |
| 0-69 | FAIL |

## Category details

### Compose Validation: 20 points

| Criterion | Points |
| --- | ---: |
| Source version and Compose topology recorded | 4 |
| Images build or pull successfully | 4 |
| Services start successfully | 4 |
| Expected endpoints are reachable | 4 |
| Smoke tests pass and logs are captured | 4 |

Baseline failure caps the total experiment score at 69 unless the failure is proven to be an upstream source limitation unrelated to migration.

### Migration Quality: 20 points

| Criterion | Points |
| --- | ---: |
| All Compose services are mapped or explicitly justified | 5 |
| Ports, environment variables, dependencies, and startup ordering are preserved | 5 |
| Aspire-native resources are used where appropriate | 4 |
| Secrets are not hardcoded and configuration is maintainable | 3 |
| Migration report documents topology, rationale, and differences | 3 |

Hardcoded secrets or omitted required services should normally result in zero points for this category.

### Aspire Build: 15 points

| Criterion | Points |
| --- | ---: |
| Dependency restore succeeds | 4 |
| `dotnet build` succeeds | 7 |
| Configuration is valid for local DevBox execution | 2 |
| Build warnings are resolved or documented | 2 |

Build failure caps the total experiment score at 69 because runtime validation cannot be completed.

### Aspire Runtime: 20 points

| Criterion | Points |
| --- | ---: |
| AppHost starts successfully | 5 |
| Required resources start successfully | 5 |
| Expected endpoints are reachable | 4 |
| Smoke tests pass | 4 |
| Runtime logs are captured | 2 |

Runtime failure caps the total experiment score at 79 unless a documented environment failure prevents only a non-critical validation step.

### Functional Equivalence: 15 points

| Criterion | Points |
| --- | ---: |
| User-visible workflow is preserved | 6 |
| Compose and Aspire smoke tests cover the same behavior | 4 |
| Data flow and service interactions remain equivalent | 3 |
| Known differences are documented and justified | 2 |

Smoke tests must not be weakened to raise this score.

### Dashboard Validation: 10 points

| Criterion | Points |
| --- | ---: |
| Aspire dashboard is accessible | 3 |
| Expected resources are visible | 3 |
| Console logs are visible for relevant resources | 2 |
| Trace and metric availability is inspected and classified | 2 |

Dashboard validation evaluates the operational surface, not only OpenTelemetry availability.

## Observability limitations

Missing traces alone is not an automatic FAIL.

Missing metrics alone is not an automatic FAIL.

If the source application is not instrumented for OpenTelemetry:

- do not subtract points from Compose Validation, Aspire Build, Aspire Runtime, or Functional Equivalence solely because traces or metrics are missing;
- award the trace and metric classification points in Dashboard Validation when the limitation is inspected, evidenced, and classified correctly;
- record the result as `OBSERVABILITY_LIMITATION` or `SOURCE_LIMITATION`, not `MIGRATION_FAILURE`;
- include the limitation in the final assessment recommendations.

If traces or metrics are missing because the Aspire AppHost, dashboard, resource wiring, or runtime configuration is broken, subtract the relevant Dashboard Validation points and classify the issue as `MIGRATION_FAILURE` or `ENVIRONMENT_FAILURE`.

## Result caps

The following caps keep the final score aligned with validation risk:

| Condition | Maximum score |
| --- | ---: |
| Compose baseline cannot be validated | 69 |
| Aspire build fails | 69 |
| Aspire runtime cannot start | 79 |
| Aspire smoke tests fail | 79 |
| Evidence is insufficient to support claims | 69 |
| Secrets are committed | 69 |

Caps should be documented in the final assessment when applied.

## Final assessment format

Future reports should include:

```text
Result: PASS | PARTIAL_PASS | FAIL
Score: <0-100>

Breakdown:
- Compose Validation: <points>/20
- Migration Quality: <points>/20
- Aspire Build: <points>/15
- Aspire Runtime: <points>/20
- Functional Equivalence: <points>/15
- Dashboard Validation: <points>/10

Classifications:
- MIGRATION_FAILURE: <none or summary>
- ENVIRONMENT_FAILURE: <none or summary>
- SOURCE_LIMITATION: <none or summary>
- OBSERVABILITY_LIMITATION: <none or summary>
- DOCUMENTED_DIFFERENCE: <none or summary>
```

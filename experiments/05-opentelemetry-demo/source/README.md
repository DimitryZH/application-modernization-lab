# Upstream Source

The OpenTelemetry Demo source is intentionally not vendored into this repository.

Stage A uses a pinned clone on the Google Cloud DevBox so the full upstream repository can be inspected and executed without adding a large external source tree or nested Git metadata to this research repository.

Official repository:

```text
https://github.com/open-telemetry/opentelemetry-demo.git
```

The validated commit and clone path are recorded in the Stage A report.

Reproduce the source clone with:

```bash
git clone https://github.com/open-telemetry/opentelemetry-demo.git
git checkout <recorded-commit-sha>
```

Do not modify upstream source during Stage A.

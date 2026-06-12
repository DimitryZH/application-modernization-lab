# Stage C.1: Aspire Foundation Report

## Result

**PASS**

Stage C.1 created the Experiment 05 Aspire workspace and an empty AppHost
foundation. It established configuration-asset, parameter, and image-pinning
strategies without implementing application services, infrastructure
resources, Kafka, the OpenTelemetry Collector, or observability backends.

## Foundation Created

The Aspire workspace is located at:

```text
experiments/05-opentelemetry-demo/aspire/
```

It contains:

- `OpenTelemetryDemo.Aspire.slnx`;
- a minimal `src/AppHost/AppHost.csproj`;
- an empty orchestration entry point with secret parameter declarations;
- base AppHost settings and launch settings;
- a tracked `configuration-assets/` scaffold.

The default `Experiment05:FullMode` setting is present for later implementation
stages. Stage C.1 declares no service or container resources.

## Parameter Foundation

The AppHost declares these parameters with `secret: true` and no tracked
values:

- `postgres-password`;
- `accounting-db-password`;
- `product-catalog-db-password`;
- `product-reviews-db-password`;
- `openai-api-key`;
- `flagd-ui-secret`.

No `.env` file was created. Future sensitive values must follow the documented
secret-parameter strategy.

## Documents Created

- `docs/configuration-assets-strategy.md`
- `docs/image-pinning-strategy.md`
- `reports/stage-c1-aspire-foundation-report.md`
- `aspire/configuration-assets/README.md`

## Aspire Files Created

- `aspire/OpenTelemetryDemo.Aspire.slnx`
- `aspire/src/AppHost/AppHost.csproj`
- `aspire/src/AppHost/Program.cs`
- `aspire/src/AppHost/appsettings.json`
- `aspire/src/AppHost/appsettings.Development.json`
- `aspire/src/AppHost/Properties/launchSettings.json`

## Files Modified

- `docs/Experiment-05-Roadmap.md`

## Build Validation

Validation environment:

| Item | Result |
| --- | --- |
| .NET SDK | `10.0.109` |
| Target framework | `net10.0` |
| Aspire AppHost SDK | `13.3.5` |
| Aspire Hosting AppHost package | `13.3.5` |

Commands executed from `experiments/05-opentelemetry-demo/aspire/`:

```bash
dotnet build
dotnet build --no-restore
```

Final result:

```text
Build succeeded.
1 Warning(s)
0 Error(s)
```

The final no-restore build completed in 20.04 seconds. The initial restore build
also succeeded with zero errors after NuGet access was allowed.

## Known Issue

NuGet audit reports `NU1903` for the transitive package `MessagePack 2.5.192`,
which has a known high-severity vulnerability. The package is not directly
referenced by the AppHost. This warning does not block the Stage C.1 foundation
build, but the Aspire dependency graph should be reviewed before later runtime
or production-readiness conclusions.

## Scope Confirmation

Stage C.1 did not:

- add application services;
- add PostgreSQL or Valkey resources;
- add Kafka;
- add the OpenTelemetry Collector;
- add Grafana, Jaeger, Prometheus, or OpenSearch;
- copy upstream configuration assets;
- create image-lock entries;
- perform runtime validation;
- modify the pinned upstream source.

## Blockers

None for Stage C.1.

## Suggested Commit Message

```text
feat(experiment-05): create Aspire foundation
```

var builder = DistributedApplication.CreateBuilder(args);

var postgresPassword = builder.AddParameter("postgres-password", secret: true);
var astronomyUserPassword = builder.AddParameter("astronomy-user-password", secret: true);
var monitoringUserPassword = builder.AddParameter("monitoring-user-password", secret: true);
_ = builder.AddParameter("openai-api-key", secret: true);
_ = builder.AddParameter("flagd-ui-secret", secret: true);

builder.AddContainer("astronomy-db", "postgres", "17.8")
    .WithImageSHA256("69dddb030ab69d669d8d7c6abf67aeb448178e5270d5f123a21f4f7ac8b46a24")
    .WithEndpoint(targetPort: 5432, name: "postgres")
    .WithEnvironment("POSTGRES_PASSWORD", postgresPassword)
    .WithEnvironment("ASTRONOMY_USER_PASSWORD", astronomyUserPassword)
    .WithEnvironment("MONITORING_USER_PASSWORD", monitoringUserPassword)
    .WithBindMount("../../configuration-assets/postgres/01-init.sh", "/docker-entrypoint-initdb.d/01-init.sh", isReadOnly: true)
    .WithBindMount("../../configuration-assets/postgres/init.sql", "/opt/astronomy/init.sql", isReadOnly: true)
    .WithArgs("postgres", "-c", "shared_preload_libraries=pg_stat_statements");

builder.AddContainer("valkey-cart", "ghcr.io/valkey-io/valkey", "9.0.2-alpine3.23")
    .WithImageSHA256("68677f85c863830af7836ff07c4a13b7f085ebeff62f4dedb71499ca27d229f2")
    .WithEndpoint(targetPort: 6379, name: "valkey");

var flagd = builder.AddContainer("flagd", "ghcr.io/open-feature/flagd", "v0.14.2")
    .WithImageSHA256("ffd69c37e4ddb53ae1875ea2cc0ee7c653e2aaf317ac4f25dacc8aee8f34e59a")
    .WithEndpoint(targetPort: 8013, name: "grpc")
    .WithEndpoint(targetPort: 8016, name: "ofrep")
    .WithEnvironment("FLAGD_OTEL_COLLECTOR_URI", "otel-collector:4317")
    .WithEnvironment("FLAGD_METRICS_EXPORTER", "otel")
    .WithEnvironment("GOMEMLIMIT", "60MiB")
    .WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=latest,service.criticality=low")
    .WithEnvironment("OTEL_SERVICE_NAME", "flagd")
    .WithBindMount("../../configuration-assets/flagd/demo.flagd.json", "/etc/flagd/demo.flagd.json", isReadOnly: true)
    .WithArgs("start", "--uri", "file:./etc/flagd/demo.flagd.json");

builder.AddContainer("llm", "ghcr.io/open-telemetry/demo", "latest-llm")
    .WithImageSHA256("a4ed209d643d2ceec18cf4a34671a1e24a2d9242de8270433a6e62691881ec06")
    .WithHttpEndpoint(targetPort: 8000, name: "http")
    .WithEnvironment("FLAGD_HOST", "flagd")
    .WithEnvironment("FLAGD_PORT", "8013")
    .WithReference(flagd.GetEndpoint("grpc"))
    .WaitForStart(flagd)
    .WithHttpHealthCheck("/v1/models");

builder.Build().Run();

var builder = DistributedApplication.CreateBuilder(args);

var postgresPassword = builder.AddParameter("postgres-password", secret: true);
var astronomyUserPassword = builder.AddParameter("astronomy-user-password", secret: true);
var monitoringUserPassword = builder.AddParameter("monitoring-user-password", secret: true);
_ = builder.AddParameter("openai-api-key", secret: true);
_ = builder.AddParameter("flagd-ui-secret", secret: true);

var astronomyDb = builder.AddContainer("astronomy-db", "postgres", "17.8")
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

var kafka = builder.AddContainer("kafka", "ghcr.io/open-telemetry/demo", "latest-kafka")
    .WithImageSHA256("4baa7327e27617fca641e09417d9e1442c6511f665548b5c4f4598ea25338194")
    .WithEndpoint(targetPort: 9092, name: "broker")
    .WithEndpoint(targetPort: 9093, name: "controller")
    .WithEnvironment("KAFKA_ADVERTISED_LISTENERS", "PLAINTEXT://kafka:9092")
    .WithEnvironment("KAFKA_LISTENERS", "PLAINTEXT://kafka:9092,CONTROLLER://kafka:9093")
    .WithEnvironment("KAFKA_CONTROLLER_QUORUM_VOTERS", "1@kafka:9093")
    .WithEnvironment("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")
    .WithEnvironment("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative")
    .WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=latest,service.criticality=low")
    .WithEnvironment("OTEL_SERVICE_NAME", "kafka")
    .WithEnvironment("KAFKA_HEAP_OPTS", "-Xmx400m -Xms400m")
    .WithContainerRuntimeArgs(
        "--health-cmd=nc -z kafka 9092",
        "--health-start-period=10s",
        "--health-interval=5s",
        "--health-timeout=10s",
        "--health-retries=10");

builder.AddContainer("accounting", "ghcr.io/open-telemetry/demo", "latest-accounting")
    .WithImageSHA256("393f062da55d4311a01919d4c130e440d9cb57bcd9f8e7ded6d5bbdf8cb8b2ab")
    .WithEnvironment("KAFKA_ADDR", "kafka:9092")
    .WithEnvironment("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")
    .WithEnvironment("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative")
    .WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=latest,service.criticality=low")
    .WithEnvironment("OTEL_SERVICE_NAME", "accounting")
    .WithEnvironment("DB_CONNECTION_STRING", $"Host=astronomy-db;Username=astronomy_user;Password={astronomyUserPassword};Database=astronomy_db")
    .WithEnvironment("OTEL_DOTNET_AUTO_TRACES_ENTITYFRAMEWORKCORE_INSTRUMENTATION_ENABLED", "false")
    .WithReference(kafka.GetEndpoint("broker"))
    .WithReference(astronomyDb.GetEndpoint("postgres"))
    .WaitFor(kafka)
    .WaitForStart(astronomyDb);

builder.Build().Run();

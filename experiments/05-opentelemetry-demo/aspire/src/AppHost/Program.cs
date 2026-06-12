var builder = DistributedApplication.CreateBuilder(args);

var postgresPassword = builder.AddParameter("postgres-password", secret: true);
var astronomyUserPassword = builder.AddParameter("astronomy-user-password", secret: true);
var monitoringUserPassword = builder.AddParameter("monitoring-user-password", secret: true);
var openAiApiKey = builder.AddParameter("openai-api-key", secret: true);
var flagdUiSecret = builder.AddParameter("flagd-ui-secret", secret: true);

var astronomyDb = builder.AddContainer("astronomy-db", "postgres", "17.8")
    .WithImageSHA256("69dddb030ab69d669d8d7c6abf67aeb448178e5270d5f123a21f4f7ac8b46a24")
    .WithEndpoint(targetPort: 5432, name: "postgres")
    .WithEnvironment("POSTGRES_PASSWORD", postgresPassword)
    .WithEnvironment("ASTRONOMY_USER_PASSWORD", astronomyUserPassword)
    .WithEnvironment("MONITORING_USER_PASSWORD", monitoringUserPassword)
    .WithBindMount("../../configuration-assets/postgres/01-init.sh", "/docker-entrypoint-initdb.d/01-init.sh", isReadOnly: true)
    .WithBindMount("../../configuration-assets/postgres/init.sql", "/opt/astronomy/init.sql", isReadOnly: true)
    .WithArgs("postgres", "-c", "shared_preload_libraries=pg_stat_statements");

var valkeyCart = builder.AddContainer("valkey-cart", "ghcr.io/valkey-io/valkey", "9.0.2-alpine3.23")
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
    .WithBindMount("../../configuration-assets/flagd", "/etc/flagd")
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

var prometheus = builder.AddContainer("prometheus", "quay.io/prometheus/prometheus", "v3.9.1")
    .WithImageSHA256("1f0f50f06acaceb0f5670d2c8a658a599affe7b0d8e78b898c1035653849a702")
    .WithHttpEndpoint(targetPort: 9090, port: 9090, name: "http")
    .WithBindMount("../../configuration-assets/prometheus/prometheus-config.yaml", "/etc/prometheus/prometheus-config.yaml", isReadOnly: true)
    .WithArgs(
        "--web.console.templates=/etc/prometheus/consoles",
        "--web.console.libraries=/etc/prometheus/console_libraries",
        "--storage.tsdb.retention.time=7d",
        "--config.file=/etc/prometheus/prometheus-config.yaml",
        "--storage.tsdb.path=/prometheus",
        "--web.enable-lifecycle",
        "--web.route-prefix=/",
        "--web.enable-otlp-receiver",
        "--enable-feature=exemplar-storage")
    .WithHttpHealthCheck("/-/healthy");

var jaeger = builder.AddContainer("jaeger", "quay.io/jaegertracing/jaeger", "2.14.1")
    .WithImageSHA256("39317a963b8006d0664bb1fc4c0bbdbf7cb9dcd20b9b57c23b6ebc09ab4f3cd6")
    .WithHttpEndpoint(targetPort: 16686, name: "ui")
    .WithEndpoint(targetPort: 4317, name: "otlp-grpc")
    .WithHttpEndpoint(targetPort: 13133, name: "health")
    .WithEnvironment("JAEGER_HOST", "jaeger")
    .WithEnvironment("JAEGER_GRPC_PORT", "4317")
    .WithEnvironment("PROMETHEUS_ADDR", "prometheus:9090")
    .WithEnvironment("OTEL_COLLECTOR_HOST", "otel-collector")
    .WithEnvironment("OTEL_COLLECTOR_PORT_HTTP", "4318")
    .WithEnvironment("MEMORY_MAX_TRACES", "25000")
    .WithBindMount("../../configuration-assets/jaeger/config.yml", "/etc/jaeger/config.yml", isReadOnly: true)
    .WithArgs("--config=file:/etc/jaeger/config.yml")
    .WithReference(prometheus.GetEndpoint("http"))
    .WithHttpHealthCheck("/status", endpointName: "health");

var opensearch = builder.AddContainer("opensearch", "ghcr.io/open-telemetry/demo", "latest-opensearch")
    .WithImageSHA256("b56ba5f10cce29854dbfcdb4fbe561e733681dd542e5eaa55ff67b335e532858")
    .WithHttpEndpoint(targetPort: 9200, name: "http")
    .WithEnvironment("cluster.name", "demo-cluster")
    .WithEnvironment("node.name", "demo-node")
    .WithEnvironment("bootstrap.memory_lock", "true")
    .WithEnvironment("discovery.type", "single-node")
    .WithEnvironment("OPENSEARCH_JAVA_OPTS", "-Xms400m -Xmx400m")
    .WithEnvironment("DISABLE_INSTALL_DEMO_CONFIG", "true")
    .WithEnvironment("DISABLE_SECURITY_PLUGIN", "true")
    .WithContainerRuntimeArgs(
        "--ulimit=memlock=-1:-1",
        "--ulimit=nofile=65536:65536",
        "--health-cmd=curl -s http://localhost:9200/_cluster/health | grep -E '\"status\":\"(green|yellow)\"'",
        "--health-start-period=10s",
        "--health-interval=5s",
        "--health-timeout=10s",
        "--health-retries=10")
    .WithHttpHealthCheck("/_cluster/health");

var grafana = builder.AddContainer("grafana", "grafana/grafana", "13.0.1")
    .WithImageSHA256("0f86bada30d65ef9d0183b90c1e2682ac92d53d95da8bed322b984ea78a4a73a")
    .WithHttpEndpoint(targetPort: 3000, name: "http")
    .WithEnvironment("GF_INSTALL_PLUGINS", "grafana-opensearch-datasource")
    .WithBindMount("../../configuration-assets/grafana/grafana.ini", "/etc/grafana/grafana.ini", isReadOnly: true)
    .WithBindMount("../../configuration-assets/grafana/provisioning", "/etc/grafana/provisioning", isReadOnly: true)
    .WithReference(prometheus.GetEndpoint("http"))
    .WithReference(jaeger.GetEndpoint("ui"))
    .WithReference(opensearch.GetEndpoint("http"))
    .WithHttpHealthCheck("/api/health");

var otelCollector = builder.AddContainer("otel-collector", "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib", "0.151.0")
    .WithImageSHA256("d57bfe8eee2378f31cb1193239fbcac521d54a5a071fca2bfc106916a32b892d")
    .WithEndpoint(targetPort: 4317, name: "otlp-grpc")
    .WithHttpEndpoint(targetPort: 4318, name: "otlp-http")
    .WithEnvironment("AD_PROMETHEUS_PORT", "9465")
    .WithEnvironment("FRONTEND_PROXY_ADDR", "frontend-proxy:8080")
    .WithEnvironment("GOMEMLIMIT", "160MiB")
    .WithEnvironment("HOST_FILESYSTEM", "/")
    .WithEnvironment("IMAGE_PROVIDER_HOST", "image-provider")
    .WithEnvironment("IMAGE_PROVIDER_PORT", "8081")
    .WithEnvironment("KAFKA_ADDR", "kafka:9092")
    .WithEnvironment("OTEL_COLLECTOR_HOST", "otel-collector")
    .WithEnvironment("OTEL_COLLECTOR_PORT_GRPC", "4317")
    .WithEnvironment("OTEL_COLLECTOR_PORT_HTTP", "4318")
    .WithEnvironment("POSTGRES_HOST", "astronomy-db")
    .WithEnvironment("POSTGRES_MONITORING_PASSWORD", monitoringUserPassword)
    .WithEnvironment("POSTGRES_PORT", "5432")
    .WithBindMount("../../configuration-assets/otel-collector/otelcol-config.yml", "/etc/otelcol-config.yml", isReadOnly: true)
    .WithBindMount("../../configuration-assets/otel-collector/otelcol-config-full.yml", "/etc/otelcol-config-full.yml", isReadOnly: true)
    .WithBindMount("../../configuration-assets/otel-collector/otelcol-config-observability.yml", "/etc/otelcol-config-observability.yml", isReadOnly: true)
    .WithBindMount("../../configuration-assets/otel-collector/otelcol-config-extras.yml", "/etc/otelcol-config-extras.yml", isReadOnly: true)
    .WithBindMount("/", "/hostfs", isReadOnly: true)
    .WithBindMount("/var/run/docker.sock", "/var/run/docker.sock", isReadOnly: true)
    .WithArgs(
        "--config=/etc/otelcol-config.yml",
        "--config=/etc/otelcol-config-full.yml",
        "--config=/etc/otelcol-config-observability.yml",
        "--config=/etc/otelcol-config-extras.yml",
        "--feature-gates=service.profilesSupport")
    .WithContainerRuntimeArgs("--user=0:0")
    .WithReference(jaeger.GetEndpoint("otlp-grpc"))
    .WithReference(opensearch.GetEndpoint("http"))
    .WithReference(prometheus.GetEndpoint("http"))
    .WithReference(kafka.GetEndpoint("broker"))
    .WithReference(astronomyDb.GetEndpoint("postgres"))
    .WithReference(valkeyCart.GetEndpoint("valkey"))
    .WaitForStart(jaeger)
    .WaitFor(opensearch);

var productCatalog = AddDemoService("product-catalog", "c566213e753d53026a9a61e780eee956cb29eb1f33e9aefb99ea2cab576be086", 3550,
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("GOMEMLIMIT", "16MiB"),
    ("OTEL_CONFIG_FILE", "/otel-config.yml"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=high"),
    ("OTEL_SEMCONV_STABILITY_OPT_IN", "database"), ("OTEL_SERVICE_NAME", "product-catalog"), ("PRODUCT_CATALOG_PORT", "3550"))
    .WithEnvironment("DB_CONNECTION_STRING", $"postgres://astronomy_user:{astronomyUserPassword}@astronomy-db/astronomy_db?sslmode=disable")
    .WithBindMount("../../configuration-assets/product-catalog/otel-config.yml", "/otel-config.yml", isReadOnly: true)
    .WithReference(astronomyDb.GetEndpoint("postgres")).WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"))
    .WaitForStart(astronomyDb).WaitForStart(flagd).WaitForStart(otelCollector);

var productReviews = AddDemoService("product-reviews", "37e804f6069c1188edb7d31826d5206d8f49f7347e1f544008bfe501d406528e", 3551,
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("LLM_BASE_URL", "http://llm:8000/v1"), ("LLM_HOST", "llm"), ("LLM_MODEL", "astronomy-llm"),
    ("LLM_PORT", "8000"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"), ("OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT", "true"),
    ("OTEL_PYTHON_LOG_CORRELATION", "true"), ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=medium"),
    ("OTEL_SERVICE_NAME", "product-reviews"), ("PRODUCT_CATALOG_ADDR", "product-catalog:3550"), ("PRODUCT_REVIEWS_PORT", "3551"),
    ("PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION", "python"))
    .WithEnvironment("DB_CONNECTION_STRING", $"host=astronomy-db user=astronomy_user password={astronomyUserPassword} dbname=astronomy_db")
    .WithEnvironment("OPENAI_API_KEY", openAiApiKey)
    .WithReference(astronomyDb.GetEndpoint("postgres")).WithReference(productCatalog.GetEndpoint("service")).WithReference(otelCollector.GetEndpoint("otlp-grpc"))
    .WaitForStart(astronomyDb).WaitForStart(productCatalog).WaitForStart(otelCollector);

var cart = AddDemoService("cart", "313b70555dfd05db9658e2d30660cff2ec78ce5c101e6b44890414cd1a2cff0e", 7070,
    ("ASPNETCORE_URLS", "http://*:7070"), ("CART_PORT", "7070"), ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"),
    ("VALKEY_ADDR", "valkey-cart:6379"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=high"), ("OTEL_SERVICE_NAME", "cart"))
    .WithReference(valkeyCart.GetEndpoint("valkey")).WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var recommendation = AddDemoService("recommendation", "fcc642c561bfc7ffc6262594f34e433ae127fbffc0e7ec28e2b2f34e1a470052", 9001,
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"), ("OTEL_PYTHON_LOG_CORRELATION", "true"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=medium"),
    ("OTEL_SERVICE_NAME", "recommendation"), ("PRODUCT_CATALOG_ADDR", "product-catalog:3550"),
    ("PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION", "python"), ("RECOMMENDATION_PORT", "9001"))
    .WithReference(productCatalog.GetEndpoint("service")).WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var payment = AddDemoService("payment", "f7934a1a494cd4a49eaa2e8d59dac247ea873ff682fbd7c6b1318cf3db43761d", 50051,
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("IPV6_ENABLED", "false"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=critical"),
    ("OTEL_SERVICE_NAME", "payment"), ("PAYMENT_PORT", "50051"))
    .WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var quote = AddDemoService("quote", "992a49a73e0983efa1e8b5e887b19440e2fd2f54e4cd72d21d5bfcc91c312493", 8090,
    ("IPV6_ENABLED", "false"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"), ("OTEL_PHP_AUTOLOAD_ENABLED", "true"), ("OTEL_PHP_INTERNAL_METRICS_ENABLED", "true"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=low"), ("OTEL_SERVICE_NAME", "quote"), ("QUOTE_PORT", "8090"))
    .WithReference(otelCollector.GetEndpoint("otlp-http"));

var shipping = AddDemoService("shipping", "3a048f8068e1bf0823145fa910aefade09dcf4bdb749ec26b360a2ad2520a159", 50050,
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("IPV6_ENABLED", "false"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=high"),
    ("OTEL_SERVICE_NAME", "shipping"), ("QUOTE_ADDR", "http://quote:8090"), ("SHIPPING_PORT", "50050"))
    .WithReference(quote.GetEndpoint("service")).WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var currency = AddDemoService("currency", "211611bcdc81ad1190a887fd1c155bfa2dd23e7760b0f2d0986138af39a2c809", 7001,
    ("CURRENCY_PORT", "7001"), ("IPV6_ENABLED", "false"), ("VERSION", "2.2.0"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=high"), ("OTEL_SERVICE_NAME", "currency"))
    .WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var email = AddDemoService("email", "c802eacd88bc8355ceb085be91efb5ba22f4a77812d44797bcd9e8aaa4386ab6", 6060,
    ("APP_ENV", "production"), ("EMAIL_PORT", "6060"), ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=medium"), ("OTEL_SERVICE_NAME", "email"))
    .WithReference(otelCollector.GetEndpoint("otlp-http"));

var imageProvider = AddDemoService("image-provider", "cceea30974e0126a42a8ec076ea5189e4cebc60d7fb415e56899455031cd3732", 8081,
    ("IMAGE_PROVIDER_PORT", "8081"), ("OTEL_COLLECTOR_HOST", "otel-collector"), ("OTEL_COLLECTOR_PORT_GRPC", "4317"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=low"), ("OTEL_SERVICE_NAME", "image-provider"))
    .WithReference(otelCollector.GetEndpoint("otlp-grpc"));

var ad = builder.AddContainer("ad", "ghcr.io/open-telemetry/demo", "latest-ad")
    .WithImageSHA256("59db3926ae76e1a0211d69edad8aa0456b34c2d7ae4269b85fa9a0905b68c800")
    .WithEndpoint(targetPort: 9555, name: "service").WithHttpEndpoint(targetPort: 9465, name: "metrics")
    .WithEnvironment("AD_PORT", "9555").WithEnvironment("AD_PROMETHEUS_PORT", "9465").WithEnvironment("FLAGD_HOST", "flagd").WithEnvironment("FLAGD_PORT", "8013")
    .WithEnvironment("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318").WithEnvironment("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative")
    .WithEnvironment("OTEL_LOGS_EXPORTER", "otlp").WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=medium")
    .WithEnvironment("OTEL_SERVICE_NAME", "ad").WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-http"));

var telemetryDocs = AddDemoService("telemetry-docs", "bb11606350ab98ec9729c5d0ceda0e452c1dc160dbb0fcc79da6dd869d53f903", 8000,
    ("OTEL_COLLECTOR_HOST", "otel-collector"), ("OTEL_COLLECTOR_PORT_GRPC", "4317"), ("OTEL_SERVICE_NAME", "telemetry-docs"), ("TELEMETRY_DOCS_PORT", "8000"));

var flagdUi = AddDemoService("flagd-ui", "114da8f13b35fc066e0cc64929ed76259bf49b4845b47e0dc9141e973930e6e4", 4000,
    ("FLAGD_UI_PORT", "4000"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=low"),
    ("OTEL_SERVICE_NAME", "flagd-ui"), ("PHX_HOST", "localhost"))
    .WithEnvironment("SECRET_KEY_BASE", flagdUiSecret)
    .WithBindMount("../../configuration-assets/flagd", "/app/data")
    .WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-http"));

var checkout = AddDemoService("checkout", "6271870956cdcd328a5aa4329e28d9b8081d26c5bea2d9d3f07c868d8d53f97a", 5050,
    ("CART_ADDR", "cart:7070"), ("CHECKOUT_PORT", "5050"), ("CURRENCY_ADDR", "currency:7001"), ("EMAIL_ADDR", "http://email:6060"),
    ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("GOMEMLIMIT", "16MiB"), ("KAFKA_ADDR", "kafka:9092"),
    ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"), ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=critical"),
    ("OTEL_SERVICE_NAME", "checkout"), ("PAYMENT_ADDR", "payment:50051"), ("PRODUCT_CATALOG_ADDR", "product-catalog:3550"), ("SHIPPING_ADDR", "http://shipping:50050"))
    .WithReference(cart.GetEndpoint("service")).WithReference(currency.GetEndpoint("service")).WithReference(email.GetEndpoint("service"))
    .WithReference(payment.GetEndpoint("service")).WithReference(productCatalog.GetEndpoint("service")).WithReference(shipping.GetEndpoint("service"))
    .WithReference(kafka.GetEndpoint("broker")).WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc")).WaitFor(kafka);

var fraudDetection = builder.AddContainer("fraud-detection", "ghcr.io/open-telemetry/demo", "latest-fraud-detection")
    .WithImageSHA256("1261e15a77dada6119e33e21ab1cb67770ae4c1c5a4a0cb2ebb6cf5e827758c5")
    .WithEnvironment("FLAGD_HOST", "flagd").WithEnvironment("FLAGD_PORT", "8013").WithEnvironment("KAFKA_ADDR", "kafka:9092")
    .WithEnvironment("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318").WithEnvironment("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative")
    .WithEnvironment("OTEL_INSTRUMENTATION_KAFKA_EXPERIMENTAL_SPAN_ATTRIBUTES", "true").WithEnvironment("OTEL_INSTRUMENTATION_MESSAGING_EXPERIMENTAL_RECEIVE_TELEMETRY_ENABLED", "true")
    .WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=low")
    .WithEnvironment("OTEL_SERVICE_NAME", "fraud-detection").WithReference(kafka.GetEndpoint("broker")).WithReference(otelCollector.GetEndpoint("otlp-http")).WaitFor(kafka);

var frontend = AddDemoService("frontend", "9308ce492d52d8550858b26bfc78e4408f9ad61afc41f6e4330d100f7f733c91", 8080,
    ("AD_ADDR", "ad:9555"), ("CART_ADDR", "cart:7070"), ("CHECKOUT_ADDR", "checkout:5050"), ("CURRENCY_ADDR", "currency:7001"),
    ("ENV_PLATFORM", "local"), ("FLAGD_HOST", "flagd"), ("FLAGD_PORT", "8013"), ("FRONTEND_ADDR", "frontend:8080"),
    ("OTEL_COLLECTOR_HOST", "otel-collector"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=critical"), ("OTEL_SERVICE_NAME", "frontend"),
    ("PORT", "8080"), ("PRODUCT_CATALOG_ADDR", "product-catalog:3550"), ("PRODUCT_REVIEWS_ADDR", "product-reviews:3551"),
    ("PUBLIC_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://localhost:8080/otlp-http/v1/traces"), ("RECOMMENDATION_ADDR", "recommendation:9001"),
    ("SHIPPING_ADDR", "http://shipping:50050"), ("WEB_OTEL_SERVICE_NAME", "frontend-web"))
    .WithReference(ad.GetEndpoint("service")).WithReference(cart.GetEndpoint("service")).WithReference(checkout.GetEndpoint("service"))
    .WithReference(currency.GetEndpoint("service")).WithReference(productCatalog.GetEndpoint("service")).WithReference(productReviews.GetEndpoint("service"))
    .WithReference(recommendation.GetEndpoint("service")).WithReference(shipping.GetEndpoint("service")).WithReference(imageProvider.GetEndpoint("service"))
    .WithReference(flagd.GetEndpoint("grpc")).WithReference(otelCollector.GetEndpoint("otlp-grpc"))
    .WithContainerRuntimeArgs(
        "--health-cmd=/nodejs/bin/node -e \"require('net').connect(8080,require('os').hostname(),function(){process.exit(0)}).on('error',function(){process.exit(1)})\"",
        "--health-start-period=60s", "--health-interval=10s", "--health-timeout=10s", "--health-retries=5");

var loadGenerator = AddDemoService("load-generator", "5f6451c62411ae6110b2212dd829e7151509d607d77738f65ddf43fb0af6943c", 8089,
    ("FLAGD_HOST", "flagd"), ("FLAGD_OFREP_PORT", "8016"), ("FLAGD_PORT", "8013"), ("LOCUST_AUTOSTART", "true"),
    ("LOCUST_BROWSER_TRAFFIC_ENABLED", "true"), ("LOCUST_HEADLESS", "false"), ("LOCUST_HOST", "http://frontend-proxy:8080"), ("LOCUST_USERS", "5"),
    ("LOCUST_WEB_HOST", "0.0.0.0"), ("LOCUST_WEB_PORT", "8089"), ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ("OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE", "cumulative"),
    ("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=low"),
    ("OTEL_SERVICE_NAME", "load-generator"), ("PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION", "python"))
    .WithReference(frontend.GetEndpoint("service")).WithReference(flagd.GetEndpoint("ofrep"));

var frontendProxy = builder.AddContainer("frontend-proxy", "ghcr.io/open-telemetry/demo", "latest-frontend-proxy")
    .WithImageSHA256("7ea5a4f217c03b33b862d01a9a84b6e314884c1a8d96db6004bbdb0a37a2aa79")
    .WithHttpEndpoint(targetPort: 8080, port: 8080, name: "http").WithHttpEndpoint(targetPort: 10000, port: 10000, name: "admin")
    .WithEnvironment("ENVOY_ADDR", "0.0.0.0").WithEnvironment("ENVOY_ADMIN_PORT", "10000").WithEnvironment("ENVOY_PORT", "8080")
    .WithEnvironment("FIREPIT_HOST", "firepit").WithEnvironment("FIREPIT_PORT", "8080").WithEnvironment("FLAGD_HOST", "flagd").WithEnvironment("FLAGD_PORT", "8013")
    .WithEnvironment("FLAGD_UI_HOST", "flagd-ui").WithEnvironment("FLAGD_UI_PORT", "4000").WithEnvironment("FRONTEND_HOST", "frontend").WithEnvironment("FRONTEND_PORT", "8080")
    .WithEnvironment("GRAFANA_HOST", "grafana").WithEnvironment("GRAFANA_PORT", "3000").WithEnvironment("IMAGE_PROVIDER_HOST", "image-provider").WithEnvironment("IMAGE_PROVIDER_PORT", "8081")
    .WithEnvironment("JAEGER_HOST", "jaeger").WithEnvironment("JAEGER_UI_PORT", "16686").WithEnvironment("LOCUST_WEB_HOST", "load-generator").WithEnvironment("LOCUST_WEB_PORT", "8089")
    .WithEnvironment("OTEL_COLLECTOR_HOST", "otel-collector").WithEnvironment("OTEL_COLLECTOR_PORT_GRPC", "4317").WithEnvironment("OTEL_COLLECTOR_PORT_HTTP", "4318")
    .WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", "service.namespace=opentelemetry-demo,service.version=2.2.0,service.criticality=critical")
    .WithEnvironment("OTEL_SERVICE_NAME", "frontend-proxy").WithEnvironment("TELEMETRY_DOCS_HOST", "telemetry-docs").WithEnvironment("TELEMETRY_DOCS_PORT", "8000")
    .WithReference(frontend.GetEndpoint("service")).WithReference(loadGenerator.GetEndpoint("service")).WithReference(flagdUi.GetEndpoint("service"))
    .WithReference(telemetryDocs.GetEndpoint("service")).WithReference(grafana.GetEndpoint("http")).WithReference(jaeger.GetEndpoint("ui"))
    .WithReference(otelCollector.GetEndpoint("otlp-grpc")).WaitFor(frontend);

builder.Build().Run();

IResourceBuilder<ContainerResource> AddDemoService(string name, string digest, int port, params (string Name, string Value)[] environment)
{
    var resource = builder.AddContainer(name, "ghcr.io/open-telemetry/demo", $"latest-{name}")
        .WithImageSHA256(digest)
        .WithEndpoint(targetPort: port, name: "service");

    foreach (var (environmentName, value) in environment)
    {
        resource.WithEnvironment(environmentName, value);
    }

    return resource;
}

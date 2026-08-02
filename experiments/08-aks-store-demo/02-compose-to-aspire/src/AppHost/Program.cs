using Microsoft.Extensions.Configuration;

var builder = DistributedApplication.CreateBuilder(args);

const string demoUser = "username";
const string demoPassword = "password";
const string queueName = "orders";
const string orderDbUri = "mongodb://documentdb:10260/?tls=true&tlsAllowInvalidCertificates=true";

var baseline = Path.GetFullPath(Path.Combine(
    builder.AppHostDirectory,
    "..",
    "..",
    "..",
    "01-compose-baseline",
    "src"));

var documentDb = builder.AddContainer(
        "documentdb",
        "ghcr.io/documentdb/documentdb/documentdb-local:pg17-0.112.0")
    .WithArgs("--username", demoUser, "--password", demoPassword);

var rabbitMq = builder.AddContainer("rabbitmq", "rabbitmq:4.3.2-management-alpine")
    .WithEnvironment("RABBITMQ_DEFAULT_USER", demoUser)
    .WithEnvironment("RABBITMQ_DEFAULT_PASS", demoPassword);

var orderService = AddBaselineDockerfile("order-service")
    .WithEnvironment("ORDER_QUEUE_HOSTNAME", "rabbitmq")
    .WithEnvironment("ORDER_QUEUE_PORT", "5672")
    .WithEnvironment("ORDER_QUEUE_USERNAME", demoUser)
    .WithEnvironment("ORDER_QUEUE_PASSWORD", demoPassword)
    .WithEnvironment("ORDER_QUEUE_NAME", queueName)
    .WaitFor(rabbitMq);

var makelineService = AddBaselineDockerfile("makeline-service")
    .WithEnvironment("ORDER_QUEUE_URI", "amqp://rabbitmq:5672")
    .WithEnvironment("ORDER_QUEUE_USERNAME", demoUser)
    .WithEnvironment("ORDER_QUEUE_PASSWORD", demoPassword)
    .WithEnvironment("ORDER_QUEUE_NAME", queueName)
    .WithEnvironment("ORDER_DB_URI", orderDbUri)
    .WithEnvironment("ORDER_DB_NAME", "orderdb")
    .WithEnvironment("ORDER_DB_COLLECTION_NAME", "orders")
    .WithEnvironment("ORDER_DB_USERNAME", demoUser)
    .WithEnvironment("ORDER_DB_PASSWORD", demoPassword)
    .WaitFor(rabbitMq)
    .WaitFor(documentDb);

var productService = AddBaselineDockerfile("product-service")
    .WithEnvironment("AI_SERVICE_URL", "http://ai-service:5001/");

var storeFront = AddBaselineDockerfile("store-front")
    .WithHttpEndpoint(port: 8080, targetPort: 8080, name: "http", isProxied: false)
    .WaitFor(productService)
    .WaitFor(orderService);

AddBaselineDockerfile("store-admin")
    .WithHttpEndpoint(port: 8081, targetPort: 8081, name: "http", isProxied: false)
    .WaitFor(productService)
    .WaitFor(makelineService)
    .WaitFor(orderService);

AddBaselineDockerfile("virtual-customer")
    .WithEnvironment("ORDER_SERVICE_URL", "http://order-service:3000/")
    .WithEnvironment("ORDERS_PER_HOUR", "1")
    .WaitFor(orderService);

AddBaselineDockerfile("virtual-worker")
    .WithEnvironment("MAKELINE_SERVICE_URL", "http://makeline-service:3001")
    .WithEnvironment("ORDERS_PER_HOUR", "1")
    .WaitFor(makelineService);

if (builder.Configuration.GetValue("AksStore:EnableAiService", false))
{
    AddBaselineDockerfile("ai-service")
        .WithEnvironment("USE_AZURE_OPENAI", "True")
        .WithEnvironment("AZURE_OPENAI_API_VERSION", "2024-12-01-preview")
        .WithEnvironment("AZURE_OPENAI_DEPLOYMENT_NAME", "")
        .WithEnvironment("AZURE_OPENAI_ENDPOINT", "")
        .WithEnvironment("AZURE_OPENAI_API_KEY", "")
        .WithEnvironment("AZURE_OPENAI_IMAGE_API_VERSION", "2025-04-01-preview")
        .WithEnvironment("AZURE_OPENAI_IMAGE_DEPLOYMENT_NAME", "")
        .WithEnvironment("AZURE_OPENAI_IMAGE_ENDPOINT", "")
        .WithHttpEndpoint(port: 5001, targetPort: 5001, name: "http", isProxied: false);
}

builder.Build().Run();

IResourceBuilder<ContainerResource> AddBaselineDockerfile(string serviceName) =>
    builder.AddDockerfile(serviceName, Path.Combine(baseline, serviceName));

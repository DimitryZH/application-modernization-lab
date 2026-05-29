var builder = DistributedApplication.CreateBuilder(args);

var postgresUser = builder.AddParameter("postgres-user", "demo", publishValueAsDefault: true);
var postgresPassword = builder.AddParameter("postgres-password", secret: true);

var postgres = builder.AddPostgres("postgres", postgresUser, postgresPassword, port: 5432)
    .WithImageTag("16")
    .WithDataVolume("postgres-data");

var database = postgres.AddDatabase("demo");

var redis = builder.AddRedis("redis", port: 6379)
    .WithImageTag("7");

var databaseUrl = ReferenceExpression.Create($"postgres://{postgresUser.Resource}:{postgresPassword.Resource}@postgres:5432/demo");
var redisUrl = ReferenceExpression.Create($"redis://redis:6379");

var api = builder.AddDockerfile("api", "../../api")
    .WithHttpEndpoint(targetPort: 8080, port: 8080)
    .WithEnvironment("APP_PORT", "8080")
    .WithEnvironment("DATABASE_URL", databaseUrl)
    .WithEnvironment("REDIS_URL", redisUrl)
    .WithReference(database)
    .WithReference(redis)
    .WaitFor(database)
    .WaitFor(redis);

builder.AddDockerfile("worker", "../../worker")
    .WithEnvironment("DATABASE_URL", databaseUrl)
    .WithEnvironment("REDIS_URL", redisUrl)
    .WithReference(database)
    .WithReference(redis)
    .WaitFor(database)
    .WaitFor(redis);

builder.AddDockerfile("frontend", "../../frontend")
    .WithHttpEndpoint(targetPort: 3000, port: 3000)
    .WithEnvironment("API_BASE_URL", "http://api:8080")
    .WithReference(api.GetEndpoint("http"))
    .WaitFor(api);

builder.Build().Run();

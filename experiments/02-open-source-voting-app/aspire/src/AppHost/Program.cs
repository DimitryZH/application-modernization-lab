var builder = DistributedApplication.CreateBuilder(args);

var postgresUser = builder.AddParameter("postgres-user", "postgres", publishValueAsDefault: true);
var postgresPassword = builder.AddParameter("postgres-password", "postgres", secret: true);

var postgresUserValue = ReferenceExpression.Create($"{postgresUser.Resource}");
var postgresPasswordValue = ReferenceExpression.Create($"{postgresPassword.Resource}");

var db = builder.AddPostgres("db", postgresUser, postgresPassword, port: 5432)
    .WithImageTag("15-alpine")
    .WithDataVolume("voting-app-postgres-data");

var postgresDatabase = db.AddDatabase("postgres");

var redis = builder.AddRedis("redis", port: 6379)
    .WithImageTag("alpine");

var vote = builder.AddContainer("vote", "dockersamples/examplevotingapp_vote")
    .WithHttpEndpoint(name: "http", port: 8080, targetPort: 80)
    .WithEnvironment("REDIS_HOST", "redis")
    .WithReference(redis)
    .WaitFor(redis);

var result = builder.AddContainer("result", "dockersamples/examplevotingapp_result")
    .WithHttpEndpoint(name: "http", port: 8081, targetPort: 80)
    .WithEnvironment("POSTGRES_HOST", "db")
    .WithEnvironment("POSTGRES_USER", postgresUserValue)
    .WithEnvironment("POSTGRES_PASSWORD", postgresPasswordValue)
    .WithEnvironment("POSTGRES_DB", "postgres")
    .WithReference(postgresDatabase)
    .WaitFor(postgresDatabase);

builder.AddContainer("worker", "dockersamples/examplevotingapp_worker")
    .WithEnvironment("REDIS_HOST", "redis")
    .WithEnvironment("POSTGRES_HOST", "db")
    .WithEnvironment("POSTGRES_USER", postgresUserValue)
    .WithEnvironment("POSTGRES_PASSWORD", postgresPasswordValue)
    .WithEnvironment("POSTGRES_DB", "postgres")
    .WithReference(redis)
    .WithReference(postgresDatabase)
    .WaitFor(redis)
    .WaitFor(postgresDatabase);

builder.Build().Run();

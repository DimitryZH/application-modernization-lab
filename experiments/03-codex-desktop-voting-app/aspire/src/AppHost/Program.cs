var builder = DistributedApplication.CreateBuilder(args);

string SourcePath(params string[] paths) =>
    Path.GetFullPath(Path.Combine(
        new[] { builder.AppHostDirectory, "..", "..", "..", "source" }
            .Concat(paths)
            .ToArray()));

var postgresUser = builder.AddParameter("postgres-user", "postgres", publishValueAsDefault: true);
var postgresPassword = builder.AddParameter("postgres-password", secret: true);

var db = builder.AddPostgres("db", postgresUser, postgresPassword)
    .WithImageTag("15-alpine")
    .WithDataVolume("voting-app-03-postgres-data");

var redis = builder.AddRedis("redis")
    .WithPassword(null!)
    .WithImageTag("alpine");

builder.AddDockerfile("vote", SourcePath("vote"), dockerfilePath: null, stage: "final")
    .WithHttpEndpoint(name: "http", port: 8080, targetPort: 80)
    .WithHttpHealthCheck("/")
    .WithReference(redis)
    .WaitFor(redis);

var worker = builder.AddDockerfile("worker", SourcePath("worker"))
    .WithReference(redis)
    .WithReference(db)
    .WaitFor(redis)
    .WaitFor(db);

builder.AddDockerfile("result", SourcePath("result"))
    .WithEntrypoint("nodemon")
    .WithArgs("--inspect=0.0.0.0", "server.js")
    .WithHttpEndpoint(name: "http", port: 8081, targetPort: 80)
    .WithEndpoint(name: "debug", scheme: "tcp", port: 9229, targetPort: 9229, isExternal: true, isProxied: false)
    .WithHttpHealthCheck("/")
    .WithReference(db)
    .WaitFor(db)
    .WaitFor(worker);

builder.Build().Run();

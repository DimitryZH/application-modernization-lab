var builder = DistributedApplication.CreateBuilder(args);

_ = builder.AddParameter("postgres-password", secret: true);
_ = builder.AddParameter("accounting-db-password", secret: true);
_ = builder.AddParameter("product-catalog-db-password", secret: true);
_ = builder.AddParameter("product-reviews-db-password", secret: true);
_ = builder.AddParameter("openai-api-key", secret: true);
_ = builder.AddParameter("flagd-ui-secret", secret: true);

builder.Build().Run();

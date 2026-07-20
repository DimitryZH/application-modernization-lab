using Microsoft.Extensions.Configuration;

var builder = DistributedApplication.CreateBuilder(args);

const string onlineBoutiqueRegistry = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo";

var redis = builder.AddContainer(
        "redis-cart",
        "redis:alpine@sha256:9d317178eceac8454a2284a9e6df2466b93c745529947f0cd42a0fa9609d7005")
    .WithArgs("redis-server", "--save", "", "--appendonly", "no");

var adService = AddOnlineBoutiqueService(
        "adservice",
        "adservice:v0.10.6@sha256:f580c4853e896dd2083f0c270c4b7aa5feda6dd56058a93b87d0c88334a4c07d")
    .WithEnvironment("PORT", "9555");

var productCatalogService = AddOnlineBoutiqueService(
        "productcatalogservice",
        "productcatalogservice:v0.10.6@sha256:fb8568ecfc948717eb07746a6ce360fb8e5f906ae8a874cbad666891f0d21790")
    .WithEnvironment("PORT", "3550")
    .WithEnvironment("DISABLE_PROFILER", "1");

var currencyService = AddOnlineBoutiqueService(
        "currencyservice",
        "currencyservice:v0.10.6@sha256:7b2f3f804555c926861d67cd22c1b7c9e32d46b81cf1a64dd3089ae424d73be9")
    .WithEnvironment("PORT", "7000")
    .WithEnvironment("DISABLE_PROFILER", "1");

var paymentService = AddOnlineBoutiqueService(
        "paymentservice",
        "paymentservice:v0.10.6@sha256:735b6d3255e2c74b0135a95cfc2337987e492f24e163c0bb9a853635876993c4")
    .WithEnvironment("PORT", "50051")
    .WithEnvironment("DISABLE_PROFILER", "1");

var shippingService = AddOnlineBoutiqueService(
        "shippingservice",
        "shippingservice:v0.10.6@sha256:8527bafff8c8776e345f2dca0641f6e8595b053ce67f9a5af66f5a85d9eaca9d")
    .WithEnvironment("PORT", "50051")
    .WithEnvironment("DISABLE_PROFILER", "1");

var emailService = AddOnlineBoutiqueService(
        "emailservice",
        "emailservice:v0.10.6@sha256:77fd45d411b3550cbd39e30bda83ed6ea23d87fd6e58e69cf9fa2808e003984d")
    .WithEnvironment("PORT", "8080")
    .WithEnvironment("DISABLE_PROFILER", "1");

var recommendationService = AddOnlineBoutiqueService(
        "recommendationservice",
        "recommendationservice:v0.10.6@sha256:5d8321f2d24132889f654f75308e541b0626e6ae0cbacf81b170e5eb0921b415")
    .WithEnvironment("PORT", "8080")
    .WithEnvironment("PRODUCT_CATALOG_SERVICE_ADDR", "productcatalogservice:3550")
    .WithEnvironment("DISABLE_PROFILER", "1")
    .WaitFor(productCatalogService);

var cartService = AddOnlineBoutiqueService(
        "cartservice",
        "cartservice:v0.10.6@sha256:b5c29ddb3238474ea8d1842f07004fedeeae47f660627ab111a613a681cd0356")
    .WithEnvironment("REDIS_ADDR", "redis-cart:6379")
    .WaitFor(redis);

var checkoutService = AddOnlineBoutiqueService(
        "checkoutservice",
        "checkoutservice:v0.10.6@sha256:ab40699b6d9e45c9a93b5427008f327fbe912465361e2ff7a1a1be7111e36134")
    .WithEnvironment("PORT", "5050")
    .WithEnvironment("PRODUCT_CATALOG_SERVICE_ADDR", "productcatalogservice:3550")
    .WithEnvironment("SHIPPING_SERVICE_ADDR", "shippingservice:50051")
    .WithEnvironment("PAYMENT_SERVICE_ADDR", "paymentservice:50051")
    .WithEnvironment("EMAIL_SERVICE_ADDR", "emailservice:8080")
    .WithEnvironment("CURRENCY_SERVICE_ADDR", "currencyservice:7000")
    .WithEnvironment("CART_SERVICE_ADDR", "cartservice:7070")
    .WaitFor(cartService)
    .WaitFor(currencyService)
    .WaitFor(emailService)
    .WaitFor(paymentService)
    .WaitFor(productCatalogService)
    .WaitFor(shippingService);

var frontend = builder.AddContainer(
        "frontend",
        $"{onlineBoutiqueRegistry}/frontend:v0.10.6@sha256:c06df08eccd78568a37292cfbe889df42fac48691b7fb05f2deeba0ae8d669ef")
    .WithEnvironment("PORT", "8080")
    .WithEnvironment("ENV_PLATFORM", "local")
    .WithEnvironment("PRODUCT_CATALOG_SERVICE_ADDR", "productcatalogservice:3550")
    .WithEnvironment("CURRENCY_SERVICE_ADDR", "currencyservice:7000")
    .WithEnvironment("CART_SERVICE_ADDR", "cartservice:7070")
    .WithEnvironment("RECOMMENDATION_SERVICE_ADDR", "recommendationservice:8080")
    .WithEnvironment("SHIPPING_SERVICE_ADDR", "shippingservice:50051")
    .WithEnvironment("CHECKOUT_SERVICE_ADDR", "checkoutservice:5050")
    .WithEnvironment("AD_SERVICE_ADDR", "adservice:9555")
    .WithEnvironment("SHOPPING_ASSISTANT_SERVICE_ADDR", "shoppingassistantservice:80")
    .WithEnvironment("ENABLE_PROFILER", "0")
    .WithHttpEndpoint(port: 8080, targetPort: 8080, name: "http")
    .WaitFor(adService)
    .WaitFor(cartService)
    .WaitFor(checkoutService)
    .WaitFor(currencyService)
    .WaitFor(productCatalogService)
    .WaitFor(recommendationService)
    .WaitFor(shippingService);

if (builder.Configuration.GetValue("OnlineBoutique:EnableLoadGenerator", false))
{
    AddOnlineBoutiqueContainer(
            "loadgenerator",
            "loadgenerator:v0.10.6@sha256:9bed9dec88ae439b9c10e3689dee57201aad47c9abb9faf04add562481482421")
        .WithEnvironment("FRONTEND_ADDR", "frontend:8080")
        .WithEnvironment("USERS", builder.Configuration["OnlineBoutique:LoadGenerator:Users"] ?? "10")
        .WithEnvironment("RATE", builder.Configuration["OnlineBoutique:LoadGenerator:Rate"] ?? "1")
        .WaitFor(frontend);
}

builder.Build().Run();

IResourceBuilder<ContainerResource> AddOnlineBoutiqueService(string name, string image) =>
    AddOnlineBoutiqueContainer(name, image);

IResourceBuilder<ContainerResource> AddOnlineBoutiqueContainer(string name, string image) =>
    builder.AddContainer(name, $"{onlineBoutiqueRegistry}/{image}");
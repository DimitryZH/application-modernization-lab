using Microsoft.Extensions.Configuration;

var builder = DistributedApplication.CreateBuilder(args);

const string bankOfAnthosRegistry = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos";
const string publicKeyPath = "/tmp/.ssh/publickey";
const string privateKeyPath = "/tmp/.ssh/privatekey";
const string localRoutingNumber = "883745000";
var experimentDirectory = FindExperimentDirectory();
var jwtDirectory = Path.Combine(experimentDirectory, ".local", "jwt");
var publicKeyFile = Path.Combine(jwtDirectory, "jwtRS256.key.pub");
var privateKeyFile = Path.Combine(jwtDirectory, "jwtRS256.key");
var frontendPort = builder.Configuration.GetValue("BankOfAnthos:FrontendPort", 8080);

var accountsDb = AddBankContainer(
        "accounts-db",
        "accounts-db:v0.6.10@sha256:d95c4094c75f69069b915ef3adc99a8f95e43077885140cdeeb90d807ea74eff")
    .WithEnvironment("LOCAL_ROUTING_NUM", localRoutingNumber)
    .WithEnvironment("USE_DEMO_DATA", "True")
    .WithEnvironment("POSTGRES_DB", "accounts-db")
    .WithEnvironment("POSTGRES_USER", "accounts-admin")
    .WithEnvironment("POSTGRES_PASSWORD", "accounts-pwd")
    .WithVolume("bank-of-anthos-aspire-accounts-db-data", "/var/lib/postgresql/data");

var ledgerDb = AddBankContainer(
        "ledger-db",
        "ledger-db:v0.6.10@sha256:891cb7afe34f358ce7ed7002a1923b25e113b30bca44fecb10cc8b116d665a03")
    .WithEnvironment("LOCAL_ROUTING_NUM", localRoutingNumber)
    .WithEnvironment("USE_DEMO_DATA", "True")
    .WithEnvironment("POSTGRES_DB", "postgresdb")
    .WithEnvironment("POSTGRES_USER", "admin")
    .WithEnvironment("POSTGRES_PASSWORD", "password")
    .WithVolume("bank-of-anthos-aspire-ledger-db-data", "/var/lib/postgresql/data");

var userservice = AddBankService(
        "userservice",
        "userservice:v0.6.10@sha256:d8c4412edc46ab105000f721788b73301651cc43b19cee7e7302739f81882dcc")
    .WithEnvironment("ACCOUNTS_DB_URI", "postgresql://accounts-admin:accounts-pwd@accounts-db:5432/accounts-db")
    .WithEnvironment("TOKEN_EXPIRY_SECONDS", "3600")
    .WithEnvironment("PRIV_KEY_PATH", privateKeyPath)
    .WithBindMount(privateKeyFile, privateKeyPath, isReadOnly: true)
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WaitFor(accountsDb);

var contacts = AddBankService(
        "contacts",
        "contacts:v0.6.10@sha256:90d47594270e64f8dafa6da52c89ff70c2483cca0821dff2cc38b1450ac7a6b9")
    .WithEnvironment("ACCOUNTS_DB_URI", "postgresql://accounts-admin:accounts-pwd@accounts-db:5432/accounts-db")
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WaitFor(accountsDb);

var balancereader = AddBankJavaService(
        "balancereader",
        "balancereader:v0.6.10@sha256:feae443c650786c253bbfa3447d0902dd1689122c13962f97ccc37068d73733b")
    .WithEnvironment("POLL_MS", "100")
    .WithEnvironment("CACHE_SIZE", "1000000")
    .WithEnvironment("HOSTNAME", "balancereader-local-1")
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WaitFor(ledgerDb);

var transactionhistory = AddBankJavaService(
        "transactionhistory",
        "transactionhistory:v0.6.10@sha256:109cdad9c29a46af2708574ac4635dd73afa30cc020a4fef0266abcde87db744")
    .WithEnvironment("POLL_MS", "100")
    .WithEnvironment("CACHE_SIZE", "1000")
    .WithEnvironment("CACHE_MINUTES", "60")
    .WithEnvironment("HISTORY_LIMIT", "100")
    .WithEnvironment("HOSTNAME", "transactionhistory-local-1")
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WaitFor(ledgerDb);

var ledgerwriter = AddBankJavaService(
        "ledgerwriter",
        "ledgerwriter:v0.6.10@sha256:eae37de0d9b28fec7534c1ea860868c87279b0a85b405f8fd66c3d7734e3e42f")
    .WithServiceApiEnvironment()
    .WithEnvironment("HOSTNAME", "ledgerwriter-local-1")
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WaitFor(ledgerDb)
    .WaitFor(balancereader);

var frontend = AddBankService(
        "frontend",
        "frontend:v0.6.10@sha256:076294ce717309f711743fa3b72a9809c7f156edf1c4fa58505fd9f436d65345")
    .WithServiceApiEnvironment()
    .WithEnvironment("SCHEME", "http")
    .WithEnvironment("DEFAULT_USERNAME", "testuser")
    .WithEnvironment("DEFAULT_PASSWORD", "bankofanthos")
    .WithEnvironment("REGISTERED_OAUTH_CLIENT_ID", "local-aspire-only")
    .WithEnvironment("ALLOWED_OAUTH_REDIRECT_URI", "http://127.0.0.1:" + frontendPort.ToString() + "/login")
    .WithBindMount(publicKeyFile, publicKeyPath, isReadOnly: true)
    .WithHttpEndpoint(port: frontendPort, targetPort: 8080, name: "http")
    .WaitFor(userservice)
    .WaitFor(contacts)
    .WaitFor(ledgerwriter)
    .WaitFor(balancereader)
    .WaitFor(transactionhistory);

if (builder.Configuration.GetValue("BankOfAnthos:EnableLoadGenerator", false))
{
    AddBankContainer(
            "loadgenerator",
            "loadgenerator:v0.6.10@sha256:dd7e27f1b1bcbb9c85070eb900a6060d098d06d62ef03f98182424919895df83")
        .WithEnvironment("FRONTEND_ADDR", "frontend:8080")
        .WithEnvironment("USERS", builder.Configuration["BankOfAnthos:LoadGenerator:Users"] ?? "5")
        .WithEnvironment("LOG_LEVEL", builder.Configuration["BankOfAnthos:LoadGenerator:LogLevel"] ?? "error")
        .WaitFor(frontend);
}

builder.Build().Run();

IResourceBuilder<ContainerResource> AddBankService(string name, string image) =>
    AddBankContainer(name, image)
        .WithCommonEnvironment();

IResourceBuilder<ContainerResource> AddBankJavaService(string name, string image) =>
    AddBankService(name, image)
        .WithLedgerDbEnvironment()
        .WithJavaEnvironment();

IResourceBuilder<ContainerResource> AddBankContainer(string name, string image) =>
    builder.AddContainer(name, $"{bankOfAnthosRegistry}/{image}");

string FindExperimentDirectory()
{
    var directory = new DirectoryInfo(AppContext.BaseDirectory);
    while (directory is not null)
    {
        if (File.Exists(Path.Combine(directory.FullName, "README.md")) &&
            Directory.Exists(Path.Combine(directory.FullName, "scripts")) &&
            Directory.Exists(Path.Combine(directory.FullName, "src", "BankOfAnthos.AppHost")))
        {
            return directory.FullName;
        }

        directory = directory.Parent;
    }

    throw new InvalidOperationException("Could not locate the Experiment 07B Aspire directory.");
}

static class BankOfAnthosContainerExtensions
{
    private const string LocalRoutingNumber = "883745000";
    private const string PublicKeyPath = "/tmp/.ssh/publickey";
    private const string Version = "v0.6.10";
    private const string ServicePort = "8080";

    public static IResourceBuilder<ContainerResource> WithCommonEnvironment(this IResourceBuilder<ContainerResource> container) =>
        container
            .WithEnvironment("LOCAL_ROUTING_NUM", LocalRoutingNumber)
            .WithEnvironment("PUB_KEY_PATH", PublicKeyPath)
            .WithEnvironment("ENABLE_TRACING", "false")
            .WithEnvironment("LOG_LEVEL", "info")
            .WithEnvironment("VERSION", Version)
            .WithEnvironment("PORT", ServicePort);

    public static IResourceBuilder<ContainerResource> WithServiceApiEnvironment(this IResourceBuilder<ContainerResource> container) =>
        container
            .WithEnvironment("TRANSACTIONS_API_ADDR", "ledgerwriter:8080")
            .WithEnvironment("BALANCES_API_ADDR", "balancereader:8080")
            .WithEnvironment("HISTORY_API_ADDR", "transactionhistory:8080")
            .WithEnvironment("CONTACTS_API_ADDR", "contacts:8080")
            .WithEnvironment("USERSERVICE_API_ADDR", "userservice:8080");

    public static IResourceBuilder<ContainerResource> WithLedgerDbEnvironment(this IResourceBuilder<ContainerResource> container) =>
        container
            .WithEnvironment("SPRING_DATASOURCE_URL", "jdbc:postgresql://ledger-db:5432/postgresdb")
            .WithEnvironment("SPRING_DATASOURCE_USERNAME", "admin")
            .WithEnvironment("SPRING_DATASOURCE_PASSWORD", "password");

    public static IResourceBuilder<ContainerResource> WithJavaEnvironment(this IResourceBuilder<ContainerResource> container) =>
        container
            .WithEnvironment("ENABLE_METRICS", "false")
            .WithEnvironment("JVM_OPTS", "-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Xms256m -Xmx512m")
            .WithEnvironment("NAMESPACE", "default")
            .WithEnvironment("MANAGEMENT_METRICS_BINDERS_PROCESSOR_ENABLED", "false")
            .WithEnvironment("JAVA_TOOL_OPTIONS", "-XX:-UseContainerSupport");
}

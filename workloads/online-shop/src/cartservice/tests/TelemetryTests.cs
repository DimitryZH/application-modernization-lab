using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Xunit;
using cartservice;
namespace cartservice.tests;
public class TelemetryTests
{
    [Fact]
    public async Task CacheActivityRetainsParentAcrossAwait()
    {
        using var listener = new ActivityListener { ShouldListenTo = source => source.Name == "online-shop.cartservice", Sample = (ref ActivityCreationOptions<ActivityContext> options) => ActivitySamplingResult.AllDataAndRecorded };
        ActivitySource.AddActivityListener(listener);
        using var parent = Telemetry.Source.StartActivity("test.parent");
        var traceId = parent.TraceId;
        var result = await Telemetry.Cache("read", async () => { await Task.Yield(); Assert.Equal(traceId, Activity.Current.TraceId); Assert.Equal(ActivityKind.Client, Activity.Current.Kind); return 7; });
        Assert.Equal(7, result); Assert.Same(parent, Activity.Current);
    }
    [Fact]
    public void DiagnosticsPreserveSeverityCategoryAndContext()
    {
        using var listener = new ActivityListener { ShouldListenTo = source => source.Name == "online-shop.cartservice", Sample = (ref ActivityCreationOptions<ActivityContext> options) => ActivitySamplingResult.AllDataAndRecorded };
        ActivitySource.AddActivityListener(listener);
        using var parent = Telemetry.Source.StartActivity("test.diagnostic");
        var old = Console.Out; using var output = new System.IO.StringWriter();
        try {
            Console.SetOut(output);
            using var provider = new SafeLoggerProvider();
            var logger = provider.CreateLogger("Microsoft.Extensions.Caching.Redis");
            logger.Log(Microsoft.Extensions.Logging.LogLevel.Error, new Microsoft.Extensions.Logging.EventId(1), "private-canary", new Exception("private-canary"), (s,e) => s);
            Telemetry.Diagnostic("configuration", Microsoft.Extensions.Logging.LogLevel.Warning);
        } finally { Console.SetOut(old); }
        Assert.DoesNotContain("private-canary", output.ToString());
        var rows = output.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        using var first = System.Text.Json.JsonDocument.Parse(rows[0]); using var second = System.Text.Json.JsonDocument.Parse(rows[1]);
        Assert.Equal("ERROR", first.RootElement.GetProperty("severity").GetString());
        Assert.Equal("dependency", first.RootElement.GetProperty("category").GetString());
        Assert.Equal("dependency_failure", first.RootElement.GetProperty("error.type").GetString());
        Assert.Equal(parent.SpanId.ToHexString(), first.RootElement.GetProperty("span_id").GetString());
        Assert.Equal("WARN", second.RootElement.GetProperty("severity").GetString());
        Assert.Equal("configuration", second.RootElement.GetProperty("category").GetString());
    }
}

using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Net.Client;
using Hipstershop;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Hosting;
using OpenTelemetry;
using OpenTelemetry.Trace;
using Xunit;
namespace cartservice.tests;
public class FrameworkTelemetryTests
{
    private sealed class Capture : BaseProcessor<Activity>
    {
        public ConcurrentBag<Activity> Activities = new();
        public override void OnEnd(Activity activity) => Activities.Add(activity);
    }
    [Fact]
    public async Task FrameworkOwnsExactlyOneServerSpan()
    {
        var capture = new Capture();
        using var provider = Sdk.CreateTracerProviderBuilder().AddSource("Microsoft.AspNetCore", "online-shop.cartservice").AddProcessor(capture).Build();
        using var server = await new HostBuilder().ConfigureWebHost(web => web.UseStartup<cartservice.Startup>().UseTestServer()).StartAsync();
        using var http = server.GetTestClient(); using var channel = GrpcChannel.ForAddress(http.BaseAddress, new GrpcChannelOptions { HttpClient = http });
        var traceId = ActivityTraceId.CreateRandom().ToHexString();
        await new CartService.CartServiceClient(channel).GetCartAsync(new GetCartRequest { UserId = "framework-test" }, new Metadata { { "traceparent", "00-" + traceId + "-0123456789abcdef-01" } });
        for (var attempt = 0; attempt < 100 && !System.Linq.Enumerable.Any(capture.Activities, a => a.TraceId.ToHexString() == traceId && a.Kind == ActivityKind.Server); attempt++) await Task.Delay(10);
        var spans = System.Linq.Enumerable.Where(capture.Activities, a => a.TraceId.ToHexString() == traceId);
        var root = Assert.Single(spans, a => a.Kind == ActivityKind.Server);
        Assert.Equal("Microsoft.AspNetCore", root.Source.Name);
        Assert.Contains(spans, a => a.Source.Name == "online-shop.cartservice" && a.ParentSpanId == root.SpanId);
    }
}

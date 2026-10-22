// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
using System;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using System.Text;
using System.Text.Json;
using System.IO;
using System.Threading.Tasks;
using Grpc.Core;
using Grpc.Core.Interceptors;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using Microsoft.Extensions.DependencyInjection;
namespace cartservice;
public static class Telemetry
{
    public static readonly ActivitySource Source = new("online-shop.cartservice");
    private static readonly Meter Meter = new("online-shop.cartservice");
    private static readonly Counter<long> Requests = Meter.CreateCounter<long>("online_shop.transport.requests", "{request}");
    private static readonly Counter<long> Errors = Meter.CreateCounter<long>("online_shop.transport.errors", "{request}");
    private static readonly Histogram<double> Duration = Meter.CreateHistogram<double>("online_shop.transport.duration", "s");
    private static readonly Counter<long> Business = Meter.CreateCounter<long>("online_shop.business.operations", "{operation}");
    public static bool Enabled => Environment.GetEnvironmentVariable("OTEL_SDK_DISABLED") != "true" &&
        (Environment.GetEnvironmentVariable("ONLINE_SHOP_TELEMETRY_ENABLED") is string value ? value is "true" or "1" : Environment.GetEnvironmentVariable("ENABLE_TRACING") == "1");
    public static void Configure(IServiceCollection services)
    {
        services.AddLogging(builder => { builder.ClearProviders(); builder.AddProvider(new SafeLoggerProvider()); });
        if (!Enabled) return;
        var resource = ResourceBuilder.CreateDefault().AddService("cartservice", "online-shop", Environment.GetEnvironmentVariable("ONLINE_SHOP_VERSION") ?? "development")
            .AddAttributes(new[] { new System.Collections.Generic.KeyValuePair<string, object>("deployment.environment.name", Environment.GetEnvironmentVariable("ONLINE_SHOP_ENVIRONMENT") ?? "local") });
        double ratio = double.TryParse(Environment.GetEnvironmentVariable("OTEL_TRACES_SAMPLER_ARG"), System.Globalization.CultureInfo.InvariantCulture, out var parsed) && parsed >= 0 && parsed <= 1 ? parsed : .1;
        services.AddOpenTelemetry().ConfigureResource(r => r.AddAttributes(resource.Build().Attributes))
            .WithTracing(t =>
            {
                t.AddSource("Microsoft.AspNetCore", "online-shop.cartservice").SetSampler(new ParentBasedSampler(new TraceIdRatioBasedSampler(ratio)));
                if (Environment.GetEnvironmentVariable("OTEL_TRACES_EXPORTER") != "none") t.AddOtlpExporter(o => { o.TimeoutMilliseconds = 2000; o.BatchExportProcessorOptions = new BatchExportProcessorOptions<Activity> { MaxQueueSize = 512, MaxExportBatchSize = 128, ScheduledDelayMilliseconds = 1000, ExporterTimeoutMilliseconds = 2000 }; });
            })
            .WithMetrics(m =>
            {
                m.AddMeter("online-shop.cartservice").AddView("online_shop.transport.duration", new ExplicitBucketHistogramConfiguration { Boundaries = new double[] { .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10 } });
                if (Environment.GetEnvironmentVariable("OTEL_METRICS_EXPORTER") != "none") m.AddOtlpExporter((o, reader) => { o.TimeoutMilliseconds = 2000; reader.PeriodicExportingMetricReaderOptions.ExportIntervalMilliseconds = int.TryParse(Environment.GetEnvironmentVariable("OTEL_METRIC_EXPORT_INTERVAL"), out var interval) && interval >= 1000 ? interval : 10000; });
            });
    }
    public static void Record(string kind, string operation, long start, string outcome)
    {
        var tags = new TagList { { "kind", kind }, { "operation", operation }, { "outcome", outcome } };
        Requests.Add(1, tags); Duration.Record(Stopwatch.GetElapsedTime(start).TotalSeconds, tags);
        if (outcome != "ok" && outcome != "miss") { Errors.Add(1, tags); Activity.Current?.SetStatus(ActivityStatusCode.Error, "operation failed"); Activity.Current?.SetTag("error.type", outcome); }
        Log("operation.completed", operation, outcome, category: kind == "client" ? "dependency" : "application");
    }
    public static async Task<T> Cache<T>(string operation, Func<Task<T>> action)
    {
        using var activity = Source.StartActivity("cache." + operation, ActivityKind.Client);
        activity?.SetTag("db.system.name", Environment.GetEnvironmentVariable("REDIS_ADDR") is null ? "memory" : "redis");
        var start = Stopwatch.GetTimestamp(); string outcome = "ok";
        try { var result = await action(); if (operation == "read" && result is null) outcome = "miss"; return result; }
        catch { outcome = "storage_error"; throw; }
        finally { Record("client", "cache." + operation, start, outcome); }
    }
    public static Task Cache(string operation, Func<Task> action) => Cache(operation, async () => { await action(); return true; });
    public static void Count(string operation, string outcome) => Business.Add(1, new TagList { { "operation", operation }, { "outcome", outcome } });
    public static void Diagnostic(string category, LogLevel level)
    {
        if (category is not ("startup" or "configuration" or "dependency" or "application")) category = "application";
        string severity = level switch { LogLevel.Trace => "TRACE", LogLevel.Debug => "DEBUG", LogLevel.Information => "INFO", LogLevel.Warning => "WARN", LogLevel.Critical => "FATAL", _ => "ERROR" };
        string outcome = level >= LogLevel.Error ? category + "_failure" : level == LogLevel.Warning ? "warning" : "ok";
        Log(category + ".diagnostic", category, outcome, severity, category);
    }
    // Utf8JsonWriter uses no reflection metadata and survives full trimming.
    public static void Log(string name, string operation, string outcome = "ok", string severity = null, string category = "application")
    {
        using var buffer = new MemoryStream(); using (var w = new Utf8JsonWriter(buffer))
        {
            w.WriteStartObject(); w.WriteString("timestamp", DateTimeOffset.UtcNow); w.WriteString("severity", severity ?? (outcome is "ok" or "miss" ? "INFO" : "ERROR")); w.WriteString("category", category); if (outcome != "ok" && outcome != "miss") w.WriteString("error.type", outcome); w.WriteString("message", name); w.WriteString("event", name); w.WriteString("operation", operation); w.WriteString("outcome", outcome);
            w.WriteString("service.name", "cartservice"); w.WriteString("service.namespace", "online-shop"); w.WriteString("service.version", Environment.GetEnvironmentVariable("ONLINE_SHOP_VERSION") ?? "development");
            if (Activity.Current is Activity a) { w.WriteString("trace_id", a.TraceId.ToHexString()); w.WriteString("span_id", a.SpanId.ToHexString()); w.WriteNumber("trace_flags", (int)a.ActivityTraceFlags); }
            w.WriteEndObject();
        }
        Console.WriteLine(Encoding.UTF8.GetString(buffer.ToArray()));
    }
}
public sealed class TelemetryInterceptor : Interceptor
{
    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(TRequest request, ServerCallContext context, UnaryServerMethod<TRequest, TResponse> continuation)
    {
        if (context.Method.StartsWith("/grpc.health.")) return await continuation(request, context);
        // ASP.NET owns extraction and the only SERVER Activity.
        var server = Activity.Current; if (server != null) { server.DisplayName = context.Method.TrimStart('/'); server.SetTag("rpc.system", "grpc"); server.SetTag("rpc.method", context.Method); }
        using var operation = Telemetry.Source.StartActivity("cart." + context.Method.Split('/')[^1]);
        var start = Stopwatch.GetTimestamp(); string outcome = "ok";
        try { return await continuation(request, context); }
        catch (RpcException e) { outcome = e.StatusCode.ToString(); server?.SetStatus(ActivityStatusCode.Error, "rpc failed"); throw; }
        catch { outcome = "internal"; server?.SetStatus(ActivityStatusCode.Error, "rpc failed"); throw; }
        finally { Telemetry.Count(context.Method, outcome); Telemetry.Record("server", context.Method, start, outcome); }
    }
}
public sealed class SafeLoggerProvider : ILoggerProvider
{
    public ILogger CreateLogger(string categoryName) => new SafeLogger(categoryName);
    public void Dispose() { }
    private sealed class SafeLogger : ILogger
    {
        private readonly string category;
        public SafeLogger(string name) { category = name.StartsWith("Microsoft.Hosting") || name.StartsWith("Microsoft.AspNetCore.Hosting") ? "startup" : name.StartsWith("Microsoft.Extensions.Configuration") || name.StartsWith("Microsoft.Extensions.Options") ? "configuration" : name.StartsWith("Microsoft.Extensions.Caching") || name.StartsWith("StackExchange.Redis") ? "dependency" : "application"; }
        public IDisposable BeginScope<TState>(TState state) => null;
        public bool IsEnabled(LogLevel level) => level >= LogLevel.Information && level != LogLevel.None;
        public void Log<TState>(LogLevel level, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter) { if (IsEnabled(level)) Telemetry.Diagnostic(category, level); }
    }
}

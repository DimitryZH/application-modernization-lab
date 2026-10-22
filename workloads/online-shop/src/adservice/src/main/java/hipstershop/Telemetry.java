// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
package hipstershop;

import io.grpc.*;
import io.opentelemetry.api.*;
import io.opentelemetry.api.common.*;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.*;
import io.opentelemetry.api.trace.*;
import io.opentelemetry.context.*;
import io.opentelemetry.context.Context;
import io.opentelemetry.context.propagation.*;
import io.opentelemetry.exporter.otlp.metrics.*;
import io.opentelemetry.exporter.otlp.trace.*;
import io.opentelemetry.sdk.*;
import io.opentelemetry.sdk.metrics.*;
import io.opentelemetry.sdk.metrics.export.*;
import io.opentelemetry.sdk.resources.*;
import io.opentelemetry.sdk.trace.*;
import io.opentelemetry.sdk.trace.export.*;
import io.opentelemetry.sdk.trace.samplers.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

public final class Telemetry {
  static OpenTelemetry otel = OpenTelemetry.noop();
  static SdkTracerProvider traces;
  static SdkMeterProvider metrics;
  static Tracer tracer;
  static LongCounter requests, errors, business;
  static DoubleHistogram durations;

  static String env(String name, String fallback) {
    return System.getenv().getOrDefault(name, fallback);
  }

  static String legacyEndpoint() {
    String endpoint=env("COLLECTOR_SERVICE_ADDR","localhost:4317");
    return endpoint.contains("://") ? endpoint : "http://"+endpoint;
  }

  public static void init() {
    boolean enabled =
        !env("OTEL_SDK_DISABLED", "false").equals("true")
            && Set.of("true", "1")
                .contains(env("ONLINE_SHOP_TELEMETRY_ENABLED", env("ENABLE_TRACING", "false")));
    if (enabled) {
      Resource resource =
          Resource.getDefault()
              .merge(
                  Resource.create(
                      Attributes.builder()
                          .put("service.name", "adservice")
                          .put("service.namespace", "online-shop")
                          .put("service.version", env("ONLINE_SHOP_VERSION", "development"))
                          .put("service.instance.id", env("HOSTNAME", "adservice"))
                          .put(
                              "deployment.environment.name",
                              env("ONLINE_SHOP_ENVIRONMENT", "local"))
                          .build()));
      var builder = OpenTelemetrySdk.builder();
      if (!env("OTEL_TRACES_EXPORTER", "otlp").equals("none")) {
        double ratio = .1;
        try {
          ratio = Double.parseDouble(env("OTEL_TRACES_SAMPLER_ARG", ".1"));
          if (ratio < 0 || ratio > 1) ratio = .1;
        } catch (NumberFormatException ignored) {
        }
        traces =
            SdkTracerProvider.builder()
                .setResource(resource)
                .setSampler(Sampler.parentBased(Sampler.traceIdRatioBased(ratio)))
                .addSpanProcessor(
                    BatchSpanProcessor.builder(
                            OtlpGrpcSpanExporter.builder()
                                .setEndpoint(
                                    env(
                                        "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
                                        env(
                                            "OTEL_EXPORTER_OTLP_ENDPOINT",
                                            "http://localhost:4317")))
                                .setTimeout(Duration.ofSeconds(2))
                                .build())
                        .setMaxQueueSize(512)
                        .setMaxExportBatchSize(128)
                        .setScheduleDelay(Duration.ofSeconds(1))
                        .setExporterTimeout(Duration.ofSeconds(2))
                        .build())
                .build();
        builder.setTracerProvider(traces);
      }
      if (!env("OTEL_METRICS_EXPORTER", "otlp").equals("none")) {
        metrics =
            SdkMeterProvider.builder()
                .setResource(resource)
                .registerMetricReader(
                    PeriodicMetricReader.builder(
                            OtlpGrpcMetricExporter.builder()
                                .setEndpoint(
                                    env(
                                        "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT",
                                        env(
                                            "OTEL_EXPORTER_OTLP_ENDPOINT",
                                            "http://localhost:4317")))
                                .setTimeout(Duration.ofSeconds(2))
                                .build())
                        .setInterval(
                            Duration.ofMillis(
                                Math.max(
                                    1000,
                                    Long.parseLong(env("OTEL_METRIC_EXPORT_INTERVAL", "10000")))))
                        .build())
                .build();
        builder.setMeterProvider(metrics);
      }
      otel =
          builder
              .setPropagators(
                  ContextPropagators.create(
                      io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator
                          .getInstance()))
              .build();
    } else {
      otel =
          OpenTelemetry.propagating(
              ContextPropagators.create(
                  io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator.getInstance()));
    }
    tracer = otel.getTracer("online-shop.adservice");
    var meter = otel.getMeter("online-shop.adservice");
    requests = meter.counterBuilder("online_shop.transport.requests").setUnit("{request}").build();
    errors = meter.counterBuilder("online_shop.transport.errors").setUnit("{request}").build();
    business =
        meter.counterBuilder("online_shop.business.operations").setUnit("{operation}").build();
    durations =
        meter
            .histogramBuilder("online_shop.transport.duration")
            .setUnit("s")
            .setExplicitBucketBoundariesAdvice(
                Arrays.asList(.005, .01, .025, .05, .1, .25, .5, 1., 2.5, 5., 10.))
            .build();
  }

  public static void shutdown() {
    if (metrics != null) metrics.shutdown().join(3, TimeUnit.SECONDS);
    if (traces != null) traces.shutdown().join(3, TimeUnit.SECONDS);
  }

  public static void log(String event, String operation, String outcome) {
    var sc = Span.current().getSpanContext();
    System.out.println(
        "{\"timestamp\":\""
            + Instant.now()
            + "\",\"severity\":\"INFO\",\"message\":\""
            + event
            + "\",\"event\":\""
            + event
            + "\",\"operation\":\""
            + operation
            + "\",\"outcome\":\""
            + outcome
            + "\",\"service.name\":\"adservice\",\"service.namespace\":\"online-shop\",\"service.version\":\""
            + env("ONLINE_SHOP_VERSION", "development").replaceAll("[^a-zA-Z0-9._+-]", "_")
            + "\",\"trace_id\":\""
            + sc.getTraceId()
            + "\",\"span_id\":\""
            + sc.getSpanId()
            + "\",\"trace_flags\":"
            + (sc.isSampled() ? 1 : 0)
            + "}");
  }

  static final TextMapGetter<Metadata> GETTER =
      new TextMapGetter<>() {
        public Iterable<String> keys(Metadata m) {
          return m.keys();
        }

        public String get(Metadata m, String k) {
          return m.get(Metadata.Key.of(k, Metadata.ASCII_STRING_MARSHALLER));
        }
      };

  public static ServerInterceptor interceptor() {
    return new ServerInterceptor() {
      public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
          ServerCall<ReqT, RespT> call, Metadata headers, ServerCallHandler<ReqT, RespT> next) {
        String method = call.getMethodDescriptor().getFullMethodName();
        if (method.startsWith("grpc.health.")) return next.startCall(call, headers);
        Context parent =
            otel.getPropagators().getTextMapPropagator().extract(Context.root(), headers, GETTER);
        Span span =
            tracer.spanBuilder(method).setParent(parent).setSpanKind(SpanKind.SERVER).startSpan();
        Context ctx = parent.with(span);
        long start = System.nanoTime();
        ServerCall<ReqT, RespT> wrapped =
            new ForwardingServerCall.SimpleForwardingServerCall<>(call) {
              boolean ended = false;

              @Override
              public synchronized void close(Status status, Metadata trailers) {
                if (ended) return;
                try (Scope scope = ctx.makeCurrent()) {
                  if (!ended) {
                    ended = true;
                    String outcome = status.isOk() ? "ok" : status.getCode().name();
                    if (!status.isOk()) {
                      span.setStatus(StatusCode.ERROR, "rpc failed");
                      span.setAttribute("error.type", outcome);
                      errors.add(1, Attributes.of(AttributeKey.stringKey("operation"), method));
                    }
                    Attributes attrs =
                        Attributes.builder()
                            .put("operation", method)
                            .put("kind", "server")
                            .put("outcome", outcome)
                            .build();
                    requests.add(1, attrs);
                    durations.record((System.nanoTime() - start) / 1e9, attrs);
                    log("request.completed", method, outcome);
                    span.end();
                  }
                }
                super.close(status, trailers);
              }
            };
        ServerCall.Listener<ReqT> listener;
        try (Scope scope = ctx.makeCurrent()) {
          listener = next.startCall(wrapped, headers);
        }
        return new ForwardingServerCallListener.SimpleForwardingServerCallListener<>(listener) {
          @Override
          public void onMessage(ReqT message) {
            try (Scope scope = ctx.makeCurrent()) {
              super.onMessage(message);
            }
          }

          @Override
          public void onHalfClose() {
            try (Scope scope = ctx.makeCurrent()) {
              super.onHalfClose();
            }
          }

          @Override
          public void onReady() {
            try (Scope scope = ctx.makeCurrent()) {
              super.onReady();
            }
          }

          @Override
          public void onCancel() {
            try (Scope scope = ctx.makeCurrent()) {
              wrapped.close(Status.CANCELLED, new Metadata());
              super.onCancel();
            }
          }

          @Override
          public void onComplete() {
            try (Scope scope = ctx.makeCurrent()) {
              super.onComplete();
            }
          }
        };
      }
    };
  }
}

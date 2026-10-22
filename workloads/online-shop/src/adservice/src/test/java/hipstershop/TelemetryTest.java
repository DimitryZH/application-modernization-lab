package hipstershop;

import static org.junit.jupiter.api.Assertions.*;

import io.grpc.*;
import io.grpc.protobuf.ProtoUtils;
import io.opentelemetry.api.trace.Span;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

class TelemetryTest {
  @Test
  void interceptorRestoresContextAcrossCallbacks() {
    var reader = io.opentelemetry.sdk.testing.exporter.InMemoryMetricReader.create();
    var exporter = io.opentelemetry.sdk.testing.exporter.InMemorySpanExporter.create();
    var tp = io.opentelemetry.sdk.trace.SdkTracerProvider.builder().addSpanProcessor(io.opentelemetry.sdk.trace.export.SimpleSpanProcessor.create(exporter)).build();
    var mp = io.opentelemetry.sdk.metrics.SdkMeterProvider.builder().registerMetricReader(reader).build();
    Telemetry.otel = io.opentelemetry.sdk.OpenTelemetrySdk.builder().setTracerProvider(tp).setMeterProvider(mp).setPropagators(io.opentelemetry.context.propagation.ContextPropagators.create(io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator.getInstance())).build();
    Telemetry.instruments();
    var descriptor =
        MethodDescriptor.<Demo.Empty, Demo.Empty>newBuilder()
            .setType(MethodDescriptor.MethodType.UNARY)
            .setFullMethodName("hipstershop.Test/Call")
            .setRequestMarshaller(ProtoUtils.marshaller(Demo.Empty.getDefaultInstance()))
            .setResponseMarshaller(ProtoUtils.marshaller(Demo.Empty.getDefaultInstance()))
            .build();
    var closed = new AtomicInteger();
    var call =
        new ServerCall<Demo.Empty, Demo.Empty>() {
          public void request(int count) {}

          public void sendHeaders(Metadata headers) {}

          public void sendMessage(Demo.Empty message) {}

          public void close(Status status, Metadata trailers) {
            closed.incrementAndGet();
          }

          public boolean isCancelled() {
            return false;
          }

          public MethodDescriptor<Demo.Empty, Demo.Empty> getMethodDescriptor() {
            return descriptor;
          }
        };
    var headers = new Metadata();
    headers.put(
        Metadata.Key.of("traceparent", Metadata.ASCII_STRING_MARSHALLER),
        "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01");
    ServerCall.Listener<Demo.Empty> listener =
        Telemetry.interceptor()
            .interceptCall(
                call,
                headers,
                (sc, md) ->
                    new ServerCall.Listener<Demo.Empty>() {
                      @Override
                      public void onHalfClose() {
                        assertEquals(
                            "0123456789abcdef0123456789abcdef",
                            Span.current().getSpanContext().getTraceId());
                        sc.close(Status.UNAVAILABLE.withDescription("private-canary"), new Metadata());
                      }
                    });
    assertFalse(Span.current().getSpanContext().isValid());
    var output = new java.io.ByteArrayOutputStream(); var old = System.out;
    try { System.setOut(new java.io.PrintStream(output)); listener.onHalfClose(); } finally { System.setOut(old); }
    String logs = output.toString(); assertFalse(logs.contains("private-canary")); assertTrue(logs.contains("UNAVAILABLE"));
    var span=exporter.getFinishedSpanItems().get(0);assertEquals(io.opentelemetry.api.trace.StatusCode.ERROR,span.getStatus().getStatusCode());assertTrue(logs.contains(span.getSpanId()));
    int checked=0;
    for(var metric:reader.collectAllMetrics()) {
      if(!metric.getName().startsWith("online_shop.transport.")) continue;
      var points=metric.getData().getPoints();assertEquals(1,points.size());var point=points.iterator().next();
      assertEquals(io.opentelemetry.api.common.Attributes.builder().put("kind","server").put("operation","hipstershop.Test/Call").put("outcome","UNAVAILABLE").build(),point.getAttributes());
      if(metric.getName().endsWith("duration")) assertEquals(1,metric.getHistogramData().getPoints().iterator().next().getCount());
      else assertEquals(1,metric.getLongSumData().getPoints().iterator().next().getValue());checked++;
    }
    assertEquals(3,checked);tp.close();mp.close();
    assertFalse(Span.current().getSpanContext().isValid());
    assertEquals(1, closed.get());
  }
  @Test
  void diagnosticsRetainSeverityAndCategory() {
    var output=new java.io.ByteArrayOutputStream();var old=System.out;
    var span=Span.wrap(io.opentelemetry.api.trace.SpanContext.create("0123456789abcdef0123456789abcdef","0123456789abcdef",io.opentelemetry.api.trace.TraceFlags.getSampled(),io.opentelemetry.api.trace.TraceState.getDefault()));
    try(var scope=span.makeCurrent()) {System.setOut(new java.io.PrintStream(output));Telemetry.diagnostic("dependency","WARN");Telemetry.diagnostic("configuration","ERROR");}
    finally {System.setOut(old);}
    String logs=output.toString();assertTrue(logs.contains("\"severity\":\"WARN\""));assertTrue(logs.contains("\"severity\":\"ERROR\""));assertTrue(logs.contains("configuration.diagnostic"));assertTrue(logs.contains("dependency.diagnostic"));assertTrue(logs.contains(span.getSpanContext().getSpanId()));
  }
}

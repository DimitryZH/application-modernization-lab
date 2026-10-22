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
    Telemetry.init();
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
                        sc.close(Status.OK, new Metadata());
                      }
                    });
    assertFalse(Span.current().getSpanContext().isValid());
    listener.onHalfClose();
    assertFalse(Span.current().getSpanContext().isValid());
    assertEquals(1, closed.get());
  }
}

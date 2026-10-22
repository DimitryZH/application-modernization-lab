# Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
import contextlib, io, json, os, unittest
from unittest.mock import patch

os.environ["OTEL_SDK_DISABLED"] = "true"
import telemetry
from opentelemetry import propagate, trace


class Context:
    def invocation_metadata(self):
        return [
            ("traceparent", "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01")
        ]

    def code(self):
        return None


class TelemetryTests(unittest.TestCase):
    def test_parent_and_safe_log(self):
        telemetry.init()

        class Handler:
            @telemetry.rpc("hipstershop.Test/Call")
            def call(self, request, context):
                self.context = trace.get_current_span().get_span_context()
                telemetry.log("test", "test")
                return True

        output = io.StringIO()
        handler = Handler()
        with contextlib.redirect_stdout(output):
            self.assertTrue(handler.call(None, Context()))
        self.assertEqual(
            format(handler.context.trace_id, "032x"), "0123456789abcdef0123456789abcdef"
        )
        for line in output.getvalue().splitlines():
            self.assertEqual(
                json.loads(line)["trace_id"], "0123456789abcdef0123456789abcdef"
            )

    def test_post_payload_is_data_not_locust_request_name(self):
        os.environ["LOCUST_SKIP_MONKEY_PATCH"] = "1"
        import locustfile

        class Client:
            def request(self, method, path, **kwargs):
                assert kwargs["data"] == {"quantity": 2}
                assert kwargs["name"] == "/cart"
                return type("Response", (), {"status_code": 200})()

        locustfile.request(
            type("User", (), {"client": Client()})(), "POST", "/cart", {"quantity": 2}
        )

    @patch.dict(os.environ, {"OTEL_SDK_DISABLED": "false"})
    def test_http_outcomes_agree(self):
        os.environ["LOCUST_SKIP_MONKEY_PATCH"] = "1"
        import locustfile
        from unittest.mock import patch
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import SimpleSpanProcessor
        from opentelemetry.sdk.trace.export.in_memory_span_exporter import (
            InMemorySpanExporter,
        )
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import InMemoryMetricReader

        for status, outcome in [
            (503, "http_5xx"),
            (404, "http_4xx"),
            (0, "transport_error"),
            (None, "transport_error"),
            (200, "ok"),
        ]:
            exporter = InMemorySpanExporter()
            tp = TracerProvider()
            tp.add_span_processor(SimpleSpanProcessor(exporter))
            reader = InMemoryMetricReader()
            mp = MeterProvider(metric_readers=[reader])

            class Client:
                def request(self, *args, **kwargs):
                    if status is None:
                        raise OSError("private-canary")
                    return type("Response", (), {"status_code": status})()

            output = io.StringIO()
            with patch.object(telemetry, "enabled", return_value=True), patch.object(
                telemetry.trace, "get_tracer", return_value=tp.get_tracer("test")
            ), patch.object(
                telemetry.metrics, "get_meter", return_value=mp.get_meter("test")
            ), contextlib.redirect_stdout(
                output
            ):
                if status is None:
                    with self.assertRaises(OSError):
                        locustfile.request(
                            type("User", (), {"client": Client()})(), "GET", "/"
                        )
                else:
                    locustfile.request(
                        type("User", (), {"client": Client()})(), "GET", "/"
                    )
            span = exporter.get_finished_spans()[0]
            row = json.loads(output.getvalue())
            self.assertEqual(
                span.status.status_code == telemetry.StatusCode.ERROR, outcome != "ok"
            )
            self.assertEqual(row["outcome"], outcome)
            self.assertEqual(row["span_id"], format(span.context.span_id, "016x"))
            points = {
                m.name: m.data.data_points[0]
                for r in reader.get_metrics_data().resource_metrics
                for sc in r.scope_metrics
                for m in sc.metrics
            }
            for point in points.values():
                self.assertEqual(
                    dict(point.attributes),
                    {"operation": "GET /", "kind": "client", "outcome": outcome},
                )
            self.assertEqual(points["online_shop.transport.requests"].value, 1)
            self.assertEqual(points["online_shop.transport.duration"].count, 1)
            self.assertEqual(
                (
                    points.get("online_shop.transport.errors").value
                    if "online_shop.transport.errors" in points
                    else 0
                ),
                int(outcome != "ok"),
            )
            self.assertNotIn("private-canary", output.getvalue())
            tp.shutdown()
            mp.shutdown()

    def test_diagnostic_severity_category_context(self):
        import logging

        sc = trace.SpanContext(
            0x12345678901234567890123456789012, 0x1234567890123456, False
        )
        with trace.use_span(trace.NonRecordingSpan(sc)):
            for level, severity in [
                (logging.WARNING, "WARN"),
                (logging.ERROR, "ERROR"),
                (logging.CRITICAL, "FATAL"),
            ]:
                record = logging.LogRecord(
                    "private-canary", level, "", 1, "private-canary", (), None
                )
                record.telemetry_category = "dependency"
                raw = telemetry.SafeFormatter().format(record)
                row = json.loads(raw)
                self.assertEqual(row["severity"], severity)
                self.assertEqual(row["category"], "dependency")
                self.assertEqual(row["event"], "dependency.diagnostic")
                self.assertEqual(row["span_id"], format(sc.span_id, "016x"))
                self.assertNotIn("private-canary", raw)

    @patch.dict(os.environ, {"OTEL_SDK_DISABLED": "false"})
    def test_nonexception_rpc_failure_accounting(self):
        from unittest.mock import patch
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import SimpleSpanProcessor
        from opentelemetry.sdk.trace.export.in_memory_span_exporter import (
            InMemorySpanExporter,
        )
        from opentelemetry.sdk.metrics import MeterProvider
        from opentelemetry.sdk.metrics.export import InMemoryMetricReader
        import grpc

        exporter = InMemorySpanExporter()
        tp = TracerProvider()
        tp.add_span_processor(SimpleSpanProcessor(exporter))
        reader = InMemoryMetricReader()
        mp = MeterProvider(metric_readers=[reader])

        class FailedContext(Context):
            def code(self):
                return grpc.StatusCode.UNAVAILABLE

        class Handler:
            @telemetry.rpc("hipstershop.Test/Failed")
            def call(self, request, context):
                return "unchanged"

        output = io.StringIO()
        with patch.object(telemetry, "enabled", return_value=True), patch.object(
            telemetry.trace, "get_tracer", return_value=tp.get_tracer("test")
        ), patch.object(
            telemetry.metrics, "get_meter", return_value=mp.get_meter("test")
        ), contextlib.redirect_stdout(
            output
        ):
            self.assertEqual(Handler().call(None, FailedContext()), "unchanged")
        points = {
            m.name: p
            for r in reader.get_metrics_data().resource_metrics
            for scope in r.scope_metrics
            for m in scope.metrics
            for p in m.data.data_points
            if p.attributes.get("kind") == "server"
        }
        for p in points.values():
            self.assertEqual(
                dict(p.attributes),
                {
                    "operation": "hipstershop.Test/Failed",
                    "kind": "server",
                    "outcome": "UNAVAILABLE",
                },
            )
        self.assertEqual(points["online_shop.transport.errors"].value, 1)
        self.assertEqual(points["online_shop.transport.requests"].value, 1)
        self.assertEqual(points["online_shop.transport.duration"].count, 1)
        row = json.loads(output.getvalue().splitlines()[-1])
        self.assertEqual(row["outcome"], "UNAVAILABLE")
        span = exporter.get_finished_spans()[-1]
        self.assertEqual(span.status.status_code, telemetry.StatusCode.ERROR)
        self.assertEqual(row["span_id"], format(span.context.span_id, "016x"))
        tp.shutdown()
        mp.shutdown()

    def test_diagnostic_redaction(self):
        import logging

        row = telemetry.SafeFormatter().format(
            logging.LogRecord("test", 40, "", 1, "private-canary", (), None)
        )
        self.assertNotIn("private-canary", row)


if __name__ == "__main__":
    unittest.main()

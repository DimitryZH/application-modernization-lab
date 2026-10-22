# Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
import contextlib, io, json, os, unittest

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
        locustfile.request(type("User", (), {"client": Client()})(), "POST", "/cart", {"quantity": 2})

    def test_diagnostic_redaction(self):
        import logging

        row = telemetry.SafeFormatter().format(
            logging.LogRecord("test", 40, "", 1, "private-canary", (), None)
        )
        self.assertNotIn("private-canary", row)


if __name__ == "__main__":
    unittest.main()

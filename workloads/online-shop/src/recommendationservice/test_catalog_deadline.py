# Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
"""Real gRPC forwarding: no deadline must not become an overflowing timeout."""
import os
import threading
import time
import unittest
from concurrent import futures
from types import SimpleNamespace
from unittest.mock import Mock

os.environ["OTEL_SDK_DISABLED"] = "true"
import grpc
import telemetry


class CatalogDeadlineTests(unittest.TestCase):
    def test_budget_preserves_short_and_expired_deadlines(self):
        for remaining, expected in [(None, 10), (9.223372e18, 10), (30, 10), (5, 5)]:
            with self.subTest(remaining=remaining):
                context = SimpleNamespace(time_remaining=Mock(return_value=remaining))
                stub = SimpleNamespace(ListProducts=Mock(return_value="response"))
                request = object()
                self.assertEqual(telemetry.catalog_call(stub, request, context), "response")
                self.assertIs(stub.ListProducts.call_args.args[0], request)
                self.assertEqual(stub.ListProducts.call_args.kwargs["timeout"], expected)
                context.time_remaining.assert_called_once_with()

    def test_expired_deadline_does_not_call_catalog(self):
        context = SimpleNamespace(
            time_remaining=Mock(return_value=0),
            abort=Mock(side_effect=RuntimeError("aborted")),
        )
        stub = SimpleNamespace(ListProducts=Mock())
        with self.assertRaisesRegex(RuntimeError, "aborted"):
            telemetry.catalog_call(stub, object(), context)
        stub.ListProducts.assert_not_called()
        context.time_remaining.assert_called_once_with()
        context.abort.assert_called_once_with(
            grpc.StatusCode.DEADLINE_EXCEEDED, "Caller deadline expired"
        )

    def _forward_real_call(self, parent_timeout, expire=False):
        downstream = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
        proxy = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
        hits = []
        observed = []
        handler_done = threading.Event()

        def catalog(request, context):
            hits.append(request)
            return b"products"

        downstream.add_generic_rpc_handlers([grpc.method_handlers_generic_handler(
            "test.Catalog", {"ListProducts": grpc.unary_unary_rpc_method_handler(catalog)}
        )])
        port = downstream.add_insecure_port("127.0.0.1:0")
        downstream.start()
        channel = grpc.insecure_channel("127.0.0.1:" + str(port))
        call = channel.unary_unary("/test.Catalog/ListProducts")

        def forward(request, context):
            if expire:
                time.sleep(0.1)
            observed.append(context.time_remaining())
            try:
                return telemetry.catalog_call(SimpleNamespace(ListProducts=call), request, context)
            except grpc.RpcError as error:
                context.abort(error.code(), error.details())
            finally:
                handler_done.set()

        proxy.add_generic_rpc_handlers([grpc.method_handlers_generic_handler(
            "test.Recommendations", {"List": grpc.unary_unary_rpc_method_handler(forward)}
        )])
        proxy_port = proxy.add_insecure_port("127.0.0.1:0")
        proxy.start()
        caller = grpc.insecure_channel("127.0.0.1:" + str(proxy_port))
        pending = None
        try:
            grpc.channel_ready_future(channel).result(3)
            grpc.channel_ready_future(caller).result(3)
            pending = caller.unary_unary("/test.Recommendations/List").future(
                b"request", timeout=parent_timeout
            )
            if expire:
                with self.assertRaises(grpc.RpcError) as error:
                    pending.result(3)
                self.assertEqual(error.exception.code(), grpc.StatusCode.DEADLINE_EXCEEDED)
                self.assertTrue(handler_done.wait(3))
                self.assertEqual(observed, [0])
                self.assertEqual(hits, [])
                return
            self.assertEqual(pending.result(3), b"products")
            self.assertEqual(hits, [b"request"])
            if parent_timeout is None:
                self.assertGreater(observed[0], 10)
            else:
                self.assertGreater(observed[0], 0)
                self.assertLess(observed[0], parent_timeout + 0.1)
        finally:
            if pending is not None:
                pending.cancel()
            caller.close()
            channel.close()
            proxy.stop(0).wait()
            downstream.stop(0).wait()

    def test_real_rpc_without_parent_deadline(self):
        self._forward_real_call(None)

    def test_real_rpc_with_parent_deadline(self):
        self._forward_real_call(5)

    def test_real_rpc_with_short_parent_deadline(self):
        self._forward_real_call(0.25)

    def test_real_rpc_with_expired_parent_deadline(self):
        self._forward_real_call(0.05, expire=True)


if __name__ == "__main__":
    unittest.main()

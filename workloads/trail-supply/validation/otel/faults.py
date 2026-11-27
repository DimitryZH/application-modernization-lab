"""Validation-only transparent gRPC proxy and deterministic HTTP fixture."""

import json, threading, time
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import grpc
import socketserver

routes = {
    "CartService": "cartservice:7070",
    "CheckoutService": "checkoutservice:5050",
    "ProductCatalogService": "productcatalogservice:3550",
    "ShippingService": "shippingservice:50051",
    "CurrencyService": "currencyservice:7000",
    "PaymentService": "paymentservice:50051",
    "EmailService": "emailservice:8080",
    "RecommendationService": "recommendationservice:8080",
    "AdService": "adservice:9555",
}
mode = {}
captures = []
lock = threading.Lock()


class Proxy(grpc.GenericRpcHandler):
    def service(self, details):
        service = details.method.split("/")[1].split(".")[-1]
        if service not in routes:
            return None

        def invoke(request, ctx):
            with lock:
                active = dict(mode)
            if active.get("method") == details.method:
                if active.get("delay"):
                    time.sleep(active["delay"])
                if active.get("code"):
                    ctx.abort(
                        getattr(grpc.StatusCode, active["code"]),
                        "deterministic fixture failure",
                    )
            with grpc.insecure_channel(routes[service]) as channel:
                try:
                    return channel.unary_unary(details.method)(
                        request,
                        metadata=ctx.invocation_metadata(),
                        timeout=(
                            min(10, max(0.01, ctx.time_remaining()))
                            if ctx.time_remaining()
                            else 10
                        ),
                    )
                except grpc.RpcError as err:
                    ctx.abort(err.code(), "dependency failure")

        return grpc.unary_unary_rpc_method_handler(invoke)


class HTTP(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        global mode
        # Go forwards r.Body with chunked encoding. Consume it before replying;
        # unread request bytes can reset the connection and fabricate a transport error.
        self.connection.settimeout(5)
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks = []
            total = 0
            while True:
                size = int(self.rfile.readline(128).split(b";", 1)[0].strip(), 16)
                total += size
                if total > 16384:
                    self.send_error(413)
                    return
                if size == 0:
                    # This fixture does not accept trailers.
                    assert self.rfile.readline(2) == b"\r\n"
                    break
                chunks.append(self.rfile.read(size))
                assert self.rfile.read(2) == b"\r\n"
            body = b"".join(chunks)
        else:
            size = int(self.headers.get("Content-Length", "0"))
            if size > 16384:
                self.send_error(413)
                return
            body = self.rfile.read(size)
        if self.path == "/mode":
            with lock:
                mode = json.loads(body or "{}")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"{}")
            return
        self.reply({"content": "fixture", "details": {}})

    def do_GET(self):
        if self.path == "/captures":
            with lock:
                data = list(captures)
            self.reply(data)
            return
        self.reply({"weight": 1, "width": 1, "height": 1, "depth": 1})

    def reply(self, data):
        with lock:
            captures.append(
                {"traceparent": self.headers.get("traceparent"), "path": "fixture"}
            )
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())


class Blackhole(socketserver.BaseRequestHandler):
    def handle(self):
        time.sleep(20)


blackhole = socketserver.ThreadingTCPServer(("0.0.0.0", 4319), Blackhole)
blackhole.daemon_threads = True
threading.Thread(target=blackhole.serve_forever, daemon=True).start()

server = grpc.server(ThreadPoolExecutor(max_workers=30))
server.add_generic_rpc_handlers((Proxy(),))
server.add_insecure_port("[::]:50051")
server.start()
ThreadingHTTPServer(("0.0.0.0", 8081), HTTP).serve_forever()

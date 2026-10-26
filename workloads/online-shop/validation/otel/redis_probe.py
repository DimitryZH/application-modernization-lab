"""Internal-only Redis/cart probes. Never print commands, keys or session data."""
import json
import pathlib
import socket
import sys
import time
import uuid


class Redis:
    def __enter__(self):
        self.socket = socket.create_connection(("redis-cart", 6379), timeout=2)
        self.file = self.socket.makefile("rb")
        return self

    def __exit__(self, *args):
        self.file.close()
        self.socket.close()

    def command(self, *parts):
        parts = [str(p).encode() for p in parts]
        self.socket.sendall(b"*%d\r\n" % len(parts) + b"".join(b"$%d\r\n" % len(p) + p + b"\r\n" for p in parts))
        return self.read()

    def read(self):
        line = self.file.readline()
        assert line, "Redis connection closed"
        kind, value = line[:1], line[1:-2]
        if kind == b"-":
            raise AssertionError("Redis command failed")
        if kind == b":":
            return int(value)
        if kind == b"$":
            size = int(value)
            if size == -1:
                return None
            result = self.file.read(size)
            assert self.file.read(2) == b"\r\n"
            return result
        if kind == b"*":
            return [self.read() for _ in range(int(value))]
        assert kind == b"+", "Unexpected Redis reply"
        return value


def primitives():
    key = "PrivacyRedisKey-" + uuid.uuid4().hex
    with Redis() as r:
        assert r.command("PING") == b"PONG"
        assert b"redis_version:7.4.8" in r.command("INFO", "server")
        assert r.command("SET", key, "PrivacyRedisValue") == b"OK"
        assert r.command("GET", key) == b"PrivacyRedisValue"
        assert r.command("EXPIRE", key, 1) == 1
        time.sleep(1.2)
        assert r.command("GET", key) is None
        assert r.command("SET", key, "PrivacyRedisValue") == b"OK"
        assert r.command("DEL", key) == 1
        # .NET 9.0.11 IDistributedCache fields; no TTL on actual cart writes.
        assert r.command("HSET", key, "absexp", -1, "sldexp", -1, "data", "PrivacyRedisValue") == 3
        assert r.command("HMGET", key, "absexp", "sldexp", "data") == [b"-1", b"-1", b"PrivacyRedisValue"]
        assert r.command("HSET", key, "data", "PrivacyRedisUpdated") == 0
        assert r.command("HGET", key, "data") == b"PrivacyRedisUpdated"
        assert r.command("TTL", key) == -1
        assert r.command("EXPIRE", key, 1) == 1
        time.sleep(1.2)
        assert r.command("EXISTS", key) == 0
        assert r.command("CONFIG", "GET", "save") == [b"save", b""]
        assert r.command("CONFIG", "GET", "appendonly") == [b"appendonly", b"no"]
        assert r.command("SET", "restart-marker", "synthetic") == b"OK"
    # A regular file distinguishes retained storage from Redis persistence.
    print(json.dumps({"primitives": "passed", "binary_version": "7.4.8"}))


def cart(mode):
    import grpc
    from grpc_tools import protoc
    assert protoc.main(["protoc", "-I/protos", "--python_out=/tmp", "--grpc_python_out=/tmp", "/protos/demo.proto"]) == 0
    sys.path.insert(0, "/tmp")
    import demo_pb2 as pb
    import demo_pb2_grpc as rpc
    records = []
    stub = rpc.CartServiceStub(grpc.insecure_channel("cartservice:7070"))

    def call(method, request, timeout=10):
        trace, parent = uuid.uuid4().hex, uuid.uuid4().hex[:16]
        start = time.monotonic()
        try:
            result = getattr(stub, method)(request, metadata=[("traceparent", f"00-{trace}-{parent}-01")], timeout=timeout)
        except grpc.RpcError as error:
            records.append({"method": method, "trace_id": trace, "parent_id": parent, "seconds": time.monotonic() - start, "outcome": error.code().name})
            raise
        records.append({"method": method, "trace_id": trace, "parent_id": parent, "seconds": time.monotonic() - start, "outcome": "ok"})
        return result

    if mode == "outage":
        try:
            call("GetCart", pb.GetCartRequest(user_id="PrivacyRedisSession-outage"))
            raise AssertionError("Redis outage must fail")
        except grpc.RpcError as error:
            assert error.code() == grpc.StatusCode.FAILED_PRECONDITION, "must fail at dependency, before RPC deadline"
            assert records[-1]["seconds"] < 10
    else:
        # Retry readiness only, within one total deadline; functional assertions never retry.
        deadline = time.monotonic() + 45
        while True:
            try:
                stub.GetCart(pb.GetCartRequest(user_id="PrivacyRedisSession-ready"), timeout=3)
                break
            except grpc.RpcError:
                if time.monotonic() >= deadline:
                    raise AssertionError("Cart recovery deadline exceeded")
                time.sleep(.5)
        a, b = ["PrivacyRedisSession-" + uuid.uuid4().hex for _ in range(2)]
        for user in [a, b]:
            assert not call("GetCart", pb.GetCartRequest(user_id=user)).items
        call("AddItem", pb.AddItemRequest(user_id=a, item=pb.CartItem(product_id="synthetic-product", quantity=2)))
        assert call("GetCart", pb.GetCartRequest(user_id=a)).items[0].quantity == 2
        assert not call("GetCart", pb.GetCartRequest(user_id=b)).items
        call("AddItem", pb.AddItemRequest(user_id=b, item=pb.CartItem(product_id="synthetic-product", quantity=7)))
        call("AddItem", pb.AddItemRequest(user_id=a, item=pb.CartItem(product_id="synthetic-product", quantity=3)))
        assert call("GetCart", pb.GetCartRequest(user_id=a)).items[0].quantity == 5
        assert call("GetCart", pb.GetCartRequest(user_id=b)).items[0].quantity == 7
        call("EmptyCart", pb.EmptyCartRequest(user_id=a))
        assert not call("GetCart", pb.GetCartRequest(user_id=a)).items
        assert call("GetCart", pb.GetCartRequest(user_id=b)).items[0].quantity == 7
        call("EmptyCart", pb.EmptyCartRequest(user_id=b))
    result = {"phase": mode, "calls": records}
    pathlib.Path("/evidence/cart-" + mode + ".json").write_text(json.dumps(result, indent=2))
    print(json.dumps({"phase": mode, "calls": len(records), "max_seconds": max(r["seconds"] for r in records)}))


def check_kubernetes():
    import yaml
    contract = json.loads(pathlib.Path("/contract/redis.runtime.json").read_text())
    docs = list(yaml.safe_load_all(pathlib.Path("/contract/online-shop.yaml").read_text()))
    spec = next(d["spec"] for d in docs if d["kind"] == "Deployment" and d["metadata"]["name"] == "redis-cart")
    pod = spec["template"]["spec"]
    container = pod["containers"][0]
    assert container["image"] == sys.argv[2]
    assert spec["replicas"] == contract["replicas"] and spec["strategy"]["type"] == contract["updateStrategy"]
    assert container["command"] == contract["command"]
    assert container["resources"] == contract["resources"]
    assert pod["securityContext"] == dict(fsGroup=1000, runAsGroup=1000, runAsUser=1000, runAsNonRoot=True)
    assert container["securityContext"]["readOnlyRootFilesystem"] is True
    assert container["securityContext"]["capabilities"]["drop"] == ["ALL"]
    assert container["volumeMounts"] == [{"mountPath": "/data", "name": "redis-data"}]
    assert pod["volumes"] == [{"name": "redis-data", "emptyDir": {}}]
    assert pod["nodeSelector"] == {"kubernetes.io/os": "linux", "kubernetes.io/arch": "amd64"}
    assert pod["terminationGracePeriodSeconds"] == contract["shutdownSeconds"]
    for probe in ["readinessProbe", "livenessProbe"]:
        assert container[probe]["tcpSocket"]["port"] == contract["port"]
    print("PASS Kubernetes Redis runtime contract")


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "primitives":
        primitives()
    elif mode == "check-kubernetes":
        check_kubernetes()
    else:
        cart(mode)

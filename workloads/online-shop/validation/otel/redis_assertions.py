"""Assert real Redis server signals separately from application SDK signals."""
import json
from assertions import attrs, documents


def resources(root, signal, group, entries):
    for doc in documents(root / "telemetry" / (signal + ".jsonl")):
        for resource in doc.get("resource" + group, []):
            identity = attrs(resource["resource"].get("attributes", []))
            for scope in resource.get("scope" + group, []):
                for entry in scope.get(entries, []):
                    yield identity, entry


def validate(root, instance, outage=None):
    metrics = list(resources(root, "metrics", "Metrics", "metrics"))
    logs = list(resources(root, "logs", "Logs", "logRecords"))
    spans = list(resources(root, "traces", "Spans", "spans"))
    values, sample_times = {}, []
    for identity, metric in metrics:
        if identity.get("service.name") != "redis-cart":
            continue
        for key, expected in {"service.namespace": "online-shop", "service.instance.id": instance, "deployment.environment.name": "local-validation"}.items():
            assert identity.get(key) == expected, ("Redis metric identity", key)
        assert identity.get("redis.version") == "7.4.8"
        for field in ["gauge", "sum"]:
            for point in metric.get(field, {}).get("dataPoints", []):
                values.setdefault(metric["name"], []).append(float(point.get("asInt", point.get("asDouble", 0))))
                sample_times.append(int(point["timeUnixNano"]))
    for name in ["redis.uptime", "redis.memory.used", "redis.commands.processed", "redis.clients.connected", "redis.keyspace.hits", "redis.keyspace.misses"]:
        assert values.get(name) and max(values[name]) > 0, ("missing/nonpositive actual Redis metric", name)
    server_logs = []
    for identity, log in logs:
        if identity.get("service.name") != "redis-cart":
            continue
        for key, expected in {"service.namespace": "online-shop", "service.instance.id": instance, "deployment.environment.name": "local-validation"}.items():
            assert identity.get(key) == expected, ("Redis log identity", key)
        assert not log.get("traceId") and not log.get("spanId"), "native Redis log must not invent trace context"
        assert int(log.get("timeUnixNano", 0)) > 0
        server_logs.append(log.get("body", {}).get("stringValue", ""))
    assert any("Ready to accept connections" in body for body in server_logs), "missing parsed startup stdout"
    assert any("bye bye" in body for body in server_logs), "missing parsed graceful shutdown stdout"
    assert not any(identity.get("service.name") == "redis-cart" for identity, _ in spans), "invented Redis spans"
    if outage:
        assert not any(outage["stopped_ns"] + 3e9 < t < outage["restored_ns"] - 1e9 for t in sample_times), "Redis metrics continued during outage"
        assert any(t > outage["restored_ns"] for t in sample_times), "Redis metrics did not recover"
    by_id = {(s["traceId"], s["spanId"]): s for identity, s in spans if identity.get("service.name") == "cartservice"}
    for mode in ["healthy", "outage", "recovered"]:
        for call in json.loads((root / ("cart-" + mode + ".json")).read_text())["calls"]:
            tree = [s for (trace, _), s in by_id.items() if trace == call["trace_id"]]
            server = [s for s in tree if s["kind"] == 2]
            assert len(server) == 1 and server[0].get("parentSpanId") == call["parent_id"], "cart SERVER parentage"
            cache = [s for s in tree if s["name"] in ("cache.read", "cache.write")]
            assert cache, "missing logical cache spans"
            for span in cache:
                parent = by_id.get((span["traceId"], span.get("parentSpanId")))
                assert span["kind"] == 3 and parent and parent["name"].startswith("cart."), "cache CLIENT parentage"
                assert int(span["endTimeUnixNano"]) > int(span["startTimeUnixNano"])
                assert any(i.get("service.name") == "cartservice" and l.get("traceId") == span["traceId"] and l.get("spanId") == span["spanId"] for i, l in logs), "missing correlated cache completion log"
            if mode == "outage":
                assert any(s.get("status", {}).get("code") == 2 for s in cache), "missing cache error span"
    red = {}
    for identity, metric in metrics:
        if identity.get("service.name") != "cartservice" or not metric["name"].startswith("online_shop.transport."):
            continue
        for field in ["sum", "histogram"]:
            for point in metric.get(field, {}).get("dataPoints", []):
                labels = attrs(point.get("attributes", []))
                assert set(labels) == {"kind", "operation", "outcome"}
                key = (metric["name"], tuple(sorted(labels.items())))
                red[key] = max(red.get(key, 0), int(point.get("asInt", point.get("count", 0))))
    error_labels = tuple(sorted({"kind": "client", "operation": "cache.read", "outcome": "storage_error"}.items()))
    assert red.get(("online_shop.transport.errors", error_labels), 0) > 0
    for (name, labels), count in red.items():
        if name == "online_shop.transport.requests":
            assert count > 0 and red[("online_shop.transport.duration", labels)] == count
            expected = count if dict(labels)["outcome"] not in ("ok", "miss") else 0
            assert red.get(("online_shop.transport.errors", labels), 0) == expected
    for directory in ["logs", "raw", "telemetry"]:
        for path in (root / directory).glob("*"):
            content = path.read_text(errors="replace")
            for forbidden in ["PrivacyRedisKey", "PrivacyRedisValue", "PrivacyRedisSession", "synthetic-product"]:
                assert forbidden not in content, ("privacy leak", path.name)
    return {"redis_metric_maxima": {k: max(values[k]) for k in sorted(values)}, "redis_log_records": len(server_logs), "cache_spans": sum(s["name"].startswith("cache.") for s in by_id.values()), "cache_parentage_red_and_logs": "passed", "outage_recovery_metrics": "passed" if outage else "unexecuted", "privacy": "passed"}

"""OTLP JSON assertions: parentage, coverage, privacy, metrics, and log correlation."""

import json, pathlib

SERVICES = {
    "frontend",
    "checkoutservice",
    "productcatalogservice",
    "shippingservice",
    "cartservice",
    "currencyservice",
    "paymentservice",
    "emailservice",
    "recommendationservice",
    "adservice",
    "loadgenerator",
}


def attrs(values):
    return {a["key"]: next(iter(a["value"].values())) for a in values}


def documents(path):
    assert path.exists(), f"missing {path}"
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def load(root):
    spans = []
    metric_services = set()
    logs = []
    names = set()
    measurements = {}
    for doc in documents(root / "telemetry/traces.jsonl"):
        for resource in doc.get("resourceSpans", []):
            service = attrs(resource["resource"].get("attributes", [])).get(
                "service.name"
            )
            for scope in resource.get("scopeSpans", []):
                for span in scope.get("spans", []):
                    spans.append(dict(span, service=service))
    for doc in documents(root / "telemetry/metrics.jsonl"):
        for resource in doc.get("resourceMetrics", []):
            service = attrs(resource["resource"].get("attributes", [])).get(
                "service.name"
            )
            if service == "redis-cart":
                continue  # Infrastructure assertions live in redis_assertions.py.
            for scope in resource.get("scopeMetrics", []):
                for metric in scope.get("metrics", []):
                    names.add(metric["name"])
                    points = next(
                        (
                            v.get("dataPoints", [])
                            for k, v in metric.items()
                            if isinstance(v, dict)
                        ),
                        [],
                    )
                    if points:
                        metric_services.add(service)
                    for point in points:
                        if metric["name"].startswith("online_shop.transport."):
                            labels = attrs(point.get("attributes", []))
                            assert set(labels) == {"operation", "kind", "outcome"}, (
                                service,
                                metric["name"],
                                labels,
                            )
                            assert labels["kind"] in {
                                "server",
                                "client",
                                "internal",
                            }, labels
                            key = (
                                service,
                                metric["name"],
                                tuple(sorted(labels.items())),
                            )
                            value = int(
                                point.get(
                                    "asInt",
                                    point.get("asDouble", point.get("count", 0)),
                                )
                            )
                            measurements[key] = max(measurements.get(key, 0), value)
                        assert set(attrs(point.get("attributes", []))) <= {
                            "operation",
                            "kind",
                            "outcome",
                        }, point
                        if "explicitBounds" in point and metric["name"].endswith(
                            ".duration"
                        ):
                            assert point["explicitBounds"] == [
                                0.005,
                                0.01,
                                0.025,
                                0.05,
                                0.1,
                                0.25,
                                0.5,
                                1,
                                2.5,
                                5,
                                10,
                            ]
    checked = 0
    for (service, name, labels), value in measurements.items():
        if name != "online_shop.transport.requests":
            continue
        assert value > 0, (service, labels, "empty counter")
        duration = measurements.get(
            (service, "online_shop.transport.duration", labels), 0
        )
        errors = measurements.get((service, "online_shop.transport.errors", labels), 0)
        failed = dict(labels)["outcome"] not in ("ok", "miss")
        assert duration == value, (
            "duration/request count",
            service,
            labels,
            value,
            duration,
        )
        assert errors == (value if failed else 0), (
            "error/request count",
            service,
            labels,
            value,
            errors,
        )
        checked += 1
    assert checked >= len(SERVICES), "missing actual RED measurements"
    for doc in documents(root / "telemetry/logs.jsonl"):
        for resource in doc.get("resourceLogs", []):
            service = attrs(resource["resource"].get("attributes", [])).get(
                "service.name"
            )
            if service == "redis-cart":
                continue  # Native server logs have no application trace context.
            for scope in resource.get("scopeLogs", []):
                for log in scope.get("logRecords", []):
                    fields = attrs(log.get("attributes", []))
                    severity = {
                        "TRACE": 1,
                        "DEBUG": 5,
                        "INFO": 9,
                        "WARN": 13,
                        "ERROR": 17,
                        "FATAL": 21,
                    }
                    assert log.get("severityNumber") == severity[fields["severity"]], (
                        "severity mapping",
                        service,
                        log,
                    )
                    from datetime import datetime

                    assert log.get("severityText") == fields["severity"], ("severity text mapping", service, log)
                    expected = (
                        datetime.fromisoformat(
                            fields["timestamp"].replace("Z", "+00:00")
                        ).timestamp()
                        * 1e9
                    )
                    assert abs(int(log.get("timeUnixNano", 0)) - expected) < 2048, (
                        "timestamp mapping",
                        service,
                        log,
                    )
                    logs.append(dict(log, service=service))
    return spans, metric_services, logs, names


def validate(root):
    root = pathlib.Path(root)
    spans, metric_services, logs, names = load(root)
    expected_rpcs = {
        "hipstershop." + service + "/" + method
        for service, methods in {
            "CartService": ["AddItem", "GetCart", "EmptyCart"],
            "CheckoutService": ["PlaceOrder"],
            "ProductCatalogService": ["ListProducts", "GetProduct", "SearchProducts"],
            "ShippingService": ["GetQuote", "ShipOrder"],
            "CurrencyService": ["GetSupportedCurrencies", "Convert"],
            "PaymentService": ["Charge"],
            "EmailService": ["SendOrderConfirmation"],
            "RecommendationService": ["ListRecommendations"],
            "AdService": ["GetAds"],
        }.items()
        for method in methods
    }
    assert expected_rpcs <= {
        span["name"] for span in spans if span["kind"] == 2
    }, "missing RPC instrumentation"
    for span in spans:
        if span["service"] == "loadgenerator":
            assert span["kind"] == 3 and not span.get(
                "parentSpanId"
            ), "load-generator context leakage"
    assert SERVICES <= {s["service"] for s in spans}, (
        "trace coverage",
        SERVICES - {s["service"] for s in spans},
    )
    assert SERVICES <= metric_services, ("metric coverage", SERVICES - metric_services)
    by_id = {(s["traceId"], s["spanId"]): s for s in spans}
    assert len(by_id) == len(spans), "duplicate exported span"
    for record in logs:
        span = by_id.get((record.get("traceId"), record.get("spanId")))
        if span:
            assert record["service"] == span["service"], (
                "log resource mismatch",
                record["service"],
                span["service"],
            )
    correlated = {
        l["service"] for l in logs if (l.get("traceId"), l.get("spanId")) in by_id
    }
    assert SERVICES <= correlated, ("log correlation", SERVICES - correlated)
    scenarios = json.loads((root / "scenarios-full.json").read_text())
    roots = {r["trace_id"]: r for r in scenarios["requests"]}
    for request in scenarios["requests"]:
        selected = [s for s in spans if s["traceId"] == request["trace_id"]]
        if not request["sampled"]:
            assert not selected, "unsampled parent resampled"
            continue
        assert selected, ("missing trace", request)
        if request["label"].startswith("concurrent."):
            frontend = [
                s for s in selected if s["service"] == "frontend" and s["kind"] == 2
            ]
            assert len(frontend) == 1
            assert (
                frontend[0].get("parentSpanId") == request["parent_id"]
            ), "context leakage"
    for case in scenarios["rpc_cases"]:
        selected = [
            s
            for s in spans
            if s["traceId"] == case["trace_id"]
            and s["service"] == case["service"]
            and s["kind"] == 2
        ]
        assert len(selected) == 1, ("duplicate/missing RPC SERVER", case, len(selected))
    checkout = next(r for r in scenarios["requests"] if r["label"] == "full.submit")
    tree = [s for s in spans if s["traceId"] == checkout["trace_id"]]
    expected = {
        "frontend",
        "checkoutservice",
        "cartservice",
        "productcatalogservice",
        "currencyservice",
        "shippingservice",
        "paymentservice",
        "emailservice",
        "recommendationservice",
    }
    assert expected <= {s["service"] for s in tree}, (
        "checkout services",
        expected - {s["service"] for s in tree},
    )
    for span in tree:
        if span["kind"] == 2 and span["service"] != "frontend":
            parent = by_id.get((span["traceId"], span.get("parentSpanId")))
            assert parent and parent["kind"] == 3, ("broken distributed parent", span)
    for label in [
        "payment-failure.submit",
        "shipping-failure.submit",
        "not-found",
        "payment-rejection",
        "ad-timeout",
        "recommendation-failure",
    ]:
        ids = {r["trace_id"] for r in scenarios["requests"] if r["label"] == label}
        assert ids and any(
            s["traceId"] in ids and s.get("status", {}).get("code") == 2 for s in spans
        ), ("failure telemetry missing", label)
    for label, event in [
        ("email-failure.submit", "confirmation.failed"),
        ("cart-clear-failure.submit", "cart_clear.failed"),
    ]:
        ids = {r["trace_id"] for r in scenarios["requests"] if r["label"] == label}
        assert any(
            s["traceId"] in ids and any(e["name"] == event for e in s.get("events", []))
            for s in spans
        ), ("degradation event missing", event)
    all_span_ids = {s["spanId"]: s["traceId"] for s in spans}
    for span in spans:
        parent_trace = all_span_ids.get(span.get("parentSpanId"))
        assert (
            parent_trace is None or parent_trace == span["traceId"]
        ), "cross-trace parent leakage"
    for record in logs:
        request = roots.get(record.get("traceId"))
        if request and request["sampled"] and record.get("spanId"):
            assert (record["traceId"], record["spanId"]) in by_id, (
                "orphan correlated log",
                record["service"],
            )
    assert "online_shop.business.operations" in names
    # Check all raw logs, not just records accepted by Collector.
    forbidden = [
        "privacy-canary@example.invalid",
        "PrivacyCanaryStreet",
        "PrivacyCanaryCity",
        "PrivacyCanaryState",
        "PrivacyCanaryCountry",
        "4111111111111111",
        "378282246310005",
        "PrivacyCanaryBody",
        "missing-canary",
        "unknown-canary",
    ]
    for folder in ["logs", "raw", "telemetry"]:
        for path in (root / folder).glob("*"):
            text = path.read_text(encoding="utf-8", errors="replace")
            for value in forbidden:
                assert value not in text, ("sensitive content", path.name, value)
    result = {
        "red_counter_value_and_attribute_agreement": True,
        "log_timestamp_and_severity_mapping": True,
        "spans": len(spans),
        "correlated_log_records": sum(
            (l.get("traceId"), l.get("spanId")) in by_id for l in logs
        ),
        "trace_services": sorted({s["service"] for s in spans}),
        "metric_services": sorted(metric_services),
        "correlated_log_services": sorted(correlated),
        "metric_names": sorted(names),
        "checks": scenarios["checks"],
    }
    (root / "telemetry-assertions.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    import sys

    validate(sys.argv[1])

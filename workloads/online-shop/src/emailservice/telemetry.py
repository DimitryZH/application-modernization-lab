# Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
"""Explicit telemetry: no instrumentors, agents, or patched transports."""
import contextlib
import functools
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone
from opentelemetry import trace, metrics, propagate, context as otel_context
from opentelemetry.trace import SpanKind, Status, StatusCode
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.metrics.view import View, ExplicitBucketHistogramAggregation
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

SERVICE = "emailservice"
providers = []
stoppers = []
initialized = False


def enabled():
    if os.getenv("OTEL_SDK_DISABLED") == "true":
        return False
    value = os.getenv("ONLINE_SHOP_TELEMETRY_ENABLED")
    return (
        value in ("1", "true")
        if value is not None
        else os.getenv("ENABLE_TRACING") == "1"
    )


def init():
    global initialized
    if initialized:
        return
    initialized = True
    if not os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") and os.getenv("COLLECTOR_SERVICE_ADDR"):
        legacy = os.environ["COLLECTOR_SERVICE_ADDR"]
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = legacy if "://" in legacy else "http://" + legacy
    propagate.set_global_textmap(TraceContextTextMapPropagator())
    if enabled():
        resource = Resource.create(
            {
                "service.name": SERVICE,
                "service.namespace": "online-shop",
                "service.version": os.getenv("ONLINE_SHOP_VERSION", "development"),
                "service.instance.id": os.getenv("HOSTNAME", SERVICE),
                "deployment.environment.name": os.getenv(
                    "ONLINE_SHOP_ENVIRONMENT", "local"
                ),
            }
        )
        try:
            ratio = min(
                1.0, max(0.0, float(os.getenv("OTEL_TRACES_SAMPLER_ARG", "0.1")))
            )
        except ValueError:
            ratio = 0.1
        if os.getenv("OTEL_TRACES_EXPORTER") != "none":
            tp = TracerProvider(
                resource=resource, sampler=ParentBased(TraceIdRatioBased(ratio))
            )
            tp.add_span_processor(
                BatchSpanProcessor(
                    OTLPSpanExporter(timeout=2),
                    max_queue_size=512,
                    max_export_batch_size=128,
                    schedule_delay_millis=1000,
                    export_timeout_millis=2000,
                )
            )
            trace.set_tracer_provider(tp)
            providers.append(tp)
        if os.getenv("OTEL_METRICS_EXPORTER") != "none":
            mp = MeterProvider(
                resource=resource,
                metric_readers=[
                    PeriodicExportingMetricReader(
                        OTLPMetricExporter(timeout=2),
                        export_interval_millis=max(
                            1000, int(os.getenv("OTEL_METRIC_EXPORT_INTERVAL", "10000"))
                        ),
                        export_timeout_millis=2000,
                    )
                ],
                views=[
                    View(
                        instrument_type=metrics.Histogram,
                        aggregation=ExplicitBucketHistogramAggregation(
                            [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
                        ),
                    )
                ],
            )
            metrics.set_meter_provider(mp)
            providers.append(mp)
    # Exporter diagnostics contain no request objects; suppress repeated outage chatter.
    logging.getLogger("opentelemetry").setLevel(logging.CRITICAL)


def shutdown():
    # A watchdog bounds SDK implementations whose shutdown API has no timeout.
    import threading

    watchdog = threading.Timer(10, lambda: os._exit(2))
    watchdog.daemon = True
    watchdog.start()
    try:
        for stop in stoppers:
            stop()
        for provider in providers:
            provider.shutdown()
    finally:
        watchdog.cancel()


def termination(signum, frame):
    shutdown()
    raise SystemExit(0)


def install_signals():
    signal.signal(signal.SIGTERM, termination)
    signal.signal(signal.SIGINT, termination)


def log(event, operation, outcome="ok"):
    sc = trace.get_current_span().get_span_context()
    row = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "severity": "INFO",
        "message": event,
        "event": event,
        "operation": operation,
        "outcome": outcome,
        "service.name": SERVICE,
        "service.namespace": "online-shop",
        "service.version": os.getenv("ONLINE_SHOP_VERSION", "development"),
    }
    if sc.is_valid:
        row.update(
            trace_id=format(sc.trace_id, "032x"),
            span_id=format(sc.span_id, "016x"),
            trace_flags=int(sc.trace_flags),
        )
    print(json.dumps(row), flush=True)


@contextlib.contextmanager
def operation(name, kind=SpanKind.INTERNAL, parent=None):
    if not enabled():
        # The API no-op tracer does not promise to preserve an explicit parent.
        # Keep a non-recording context without constructing export workers.
        with trace.use_span(trace.get_current_span(parent), end_on_exit=False):
            yield trace.get_current_span()
            log("operation.completed", name)
        return
    start = time.monotonic()
    outcome = "ok"
    tracer = trace.get_tracer("online-shop." + SERVICE)
    with tracer.start_as_current_span(
        name,
        context=parent,
        kind=kind,
        record_exception=False,
        set_status_on_exception=False,
    ) as span:
        try:
            yield span
        except BaseException:
            outcome = "error"
            span.set_status(Status(StatusCode.ERROR, "operation failed"))
            span.set_attribute("error.type", "operation_failed")
            raise
        finally:
            meter = metrics.get_meter("online-shop." + SERVICE)
            attrs = {"operation": name, "kind": kind.name.lower(), "outcome": outcome}
            meter.create_counter(
                "online_shop.transport.requests", unit="{request}"
            ).add(1, attrs)
            meter.create_histogram("online_shop.transport.duration", unit="s").record(
                time.monotonic() - start, attrs
            )
            if outcome != "ok":
                meter.create_counter(
                    "online_shop.transport.errors", unit="{request}"
                ).add(1, attrs)
            if kind == SpanKind.INTERNAL:
                meter.create_counter(
                    "online_shop.business.operations", unit="{operation}"
                ).add(1, {"operation": name, "outcome": outcome})
            log("operation.completed", name, outcome)


def rpc(name):
    def decorate(handler):
        @functools.wraps(handler)
        def wrapped(self, request, context):
            parent = propagate.extract(dict(context.invocation_metadata()))
            with operation(name, SpanKind.SERVER, parent) as span:
                with operation(SERVICE + "." + name.rsplit("/", 1)[-1]):
                    result = handler(self, request, context)
                code = context.code() if hasattr(context, "code") else None
                if code is not None and code.name != "OK":
                    span.set_status(Status(StatusCode.ERROR, "rpc failed"))
                    span.set_attribute("error.type", code.name)
                return result

        return wrapped

    return decorate


def catalog_call(stub, request, server_context=None):
    with operation("hipstershop.ProductCatalogService/ListProducts", SpanKind.CLIENT):
        carrier = {}
        propagate.inject(carrier)
        return stub.ListProducts(
            request,
            metadata=list(carrier.items()),
            timeout=(
                server_context.time_remaining()
                if server_context and server_context.time_remaining() is not None
                else 10
            ),
        )


class SafeFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps(
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "severity": record.levelname,
                "message": "application.diagnostic",
                "service.name": SERVICE,
            }
        )


def configure_logger(name):
    logger = logging.getLogger(name)
    logger.handlers.clear()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(SafeFormatter())
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger

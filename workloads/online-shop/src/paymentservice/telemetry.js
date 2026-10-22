// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
"use strict";
const {
  context,
  trace,
  propagation,
  SpanKind,
  SpanStatusCode,
} = require("@opentelemetry/api");
const { NodeTracerProvider } = require("@opentelemetry/sdk-trace-node");
const {
  BatchSpanProcessor,
  ParentBasedSampler,
  TraceIdRatioBasedSampler,
} = require("@opentelemetry/sdk-trace-base");
const {
  MeterProvider,
  PeriodicExportingMetricReader,
} = require("@opentelemetry/sdk-metrics");
const { resourceFromAttributes } = require("@opentelemetry/resources");
const {
  OTLPTraceExporter,
} = require("@opentelemetry/exporter-trace-otlp-grpc");
const {
  OTLPMetricExporter,
} = require("@opentelemetry/exporter-metrics-otlp-grpc");
const {
  AsyncLocalStorageContextManager,
} = require("@opentelemetry/context-async-hooks");
const { W3CTraceContextPropagator } = require("@opentelemetry/core");
const service = "paymentservice";
// Preserve the previous endpoint setting while the standard variable takes precedence.
if (!process.env.OTEL_EXPORTER_OTLP_ENDPOINT && process.env.COLLECTOR_SERVICE_ADDR) {
  const legacy = process.env.COLLECTOR_SERVICE_ADDR;
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT = legacy.includes("://") ? legacy : "http://" + legacy;
}
const providers = [];
const stoppers = [];
const active =
  process.env.OTEL_SDK_DISABLED !== "true" &&
  (process.env.ONLINE_SHOP_TELEMETRY_ENABLED !== undefined
    ? ["1", "true"].includes(process.env.ONLINE_SHOP_TELEMETRY_ENABLED)
    : process.env.ENABLE_TRACING === "1");
context.setGlobalContextManager(new AsyncLocalStorageContextManager().enable());
propagation.setGlobalPropagator(new W3CTraceContextPropagator());
const resource = resourceFromAttributes({
  "service.name": service,
  "service.namespace": "online-shop",
  "service.version": process.env.ONLINE_SHOP_VERSION || "development",
  "service.instance.id": process.env.HOSTNAME || service,
  "deployment.environment.name": process.env.ONLINE_SHOP_ENVIRONMENT || "local",
});
if (active) {
  if (process.env.OTEL_TRACES_EXPORTER !== "none") {
    const ratio = Number(process.env.OTEL_TRACES_SAMPLER_ARG || ".1");
    const provider = new NodeTracerProvider({
      resource,
      sampler: new ParentBasedSampler({
        root: new TraceIdRatioBasedSampler(
          Number.isFinite(ratio) && ratio >= 0 && ratio <= 1 ? ratio : 0.1,
        ),
      }),
      spanProcessors: [
        new BatchSpanProcessor(new OTLPTraceExporter({ timeoutMillis: 2000 }), {
          maxQueueSize: 512,
          maxExportBatchSize: 128,
          scheduledDelayMillis: 1000,
          exportTimeoutMillis: 2000,
        }),
      ],
    });
    provider.register();
    providers.push(provider);
  }
  if (process.env.OTEL_METRICS_EXPORTER !== "none") {
    const provider = new MeterProvider({
      resource,
      readers: [
        new PeriodicExportingMetricReader({
          exporter: new OTLPMetricExporter({ timeoutMillis: 2000 }),
          exportIntervalMillis: Math.max(
            1000,
            Number(process.env.OTEL_METRIC_EXPORT_INTERVAL) || 10000,
          ),
          exportTimeoutMillis: 1000,
        }),
      ],
      views: [
        {
          instrumentName: "online_shop.transport.duration",
          aggregation: {
            type: 4,
            options: {
              boundaries: [
                0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10,
              ],
            },
          },
        },
      ],
    });
    require("@opentelemetry/api").metrics.setGlobalMeterProvider(provider);
    providers.push(provider);
  }
}
const tracer = trace.getTracer("online-shop." + service);
const meter = require("@opentelemetry/api").metrics.getMeter(
  "online-shop." + service,
);
const requests = meter.createCounter("online_shop.transport.requests", {
  unit: "{request}",
});
const errors = meter.createCounter("online_shop.transport.errors", {
  unit: "{request}",
});
const duration = meter.createHistogram("online_shop.transport.duration", {
  unit: "s",
});
const business = meter.createCounter("online_shop.business.operations", {
  unit: "{operation}",
});
function log(event, operation, outcome = "ok") {
  const sc = trace.getSpanContext(context.active());
  const row = {
    timestamp: new Date().toISOString(),
    severity: "INFO",
    message: event,
    event,
    operation,
    outcome,
    "service.name": service,
    "service.namespace": "online-shop",
    "service.version": process.env.ONLINE_SHOP_VERSION || "development",
  };
  if (sc && require("@opentelemetry/api").isSpanContextValid(sc)) {
    row.trace_id = sc.traceId;
    row.span_id = sc.spanId;
    row.trace_flags = sc.traceFlags;
  }
  process.stdout.write(JSON.stringify(row) + "\n");
}
const getter = {
  keys: (carrier) => Object.keys(carrier.getMap()),
  get: (carrier, key) => carrier.get(key)[0],
};
function unary(method, handler) {
  return function (call, callback) {
    const parent = propagation.extract(context.active(), call.metadata, getter);
    tracer.startActiveSpan(
      method,
      { kind: SpanKind.SERVER },
      parent,
      (span) => {
        const start = process.hrtime.bigint();
        const scoped = context.active();
        let ended = false;
        function finish(err) {
          if (ended) return;
          ended = true;
          const outcome = err ? "error" : "ok";
          if (err) {
            span.setStatus({
              code: SpanStatusCode.ERROR,
              message: "rpc failed",
            });
            span.setAttribute("error.type", "rpc_failed");
            errors.add(1, { operation: method });
          }
          const attrs = { operation: method, kind: "server", outcome };
          requests.add(1, attrs);
          duration.record(Number(process.hrtime.bigint() - start) / 1e9, attrs);
          log("request.completed", method, outcome);
          span.end();
        }
        const done = context.bind(scoped, (err, result) => {
          if (ended) return;
          finish(err);
          callback(err, result);
        });
        call.once(
          "cancelled",
          context.bind(scoped, () => finish({ code: 1 })),
        );
        try {
          handler(call, done);
        } catch (err) {
          done(err);
        }
      },
    );
  };
}
function operation(name, fn) {
  return tracer.startActiveSpan(name, (span) => {
    let outcome = "ok";
    try {
      return fn();
    } catch (err) {
      outcome = err.constructor.name;
      if (
        ![
          "InvalidCreditCard",
          "ExpiredCreditCard",
          "UnacceptedCreditCard",
        ].includes(outcome)
      )
        outcome = "error";
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: "business operation failed",
      });
      span.setAttribute("error.type", outcome);
      throw err;
    } finally {
      business.add(1, { operation: name, outcome });
      log("operation.completed", name, outcome);
      span.end();
    }
  });
}
async function shutdown() {
  const watchdog = setTimeout(() => process.exit(2), 10000);
  try {
    await Promise.all(
      stoppers.map((stop) => new Promise((resolve) => stop(resolve))),
    );
    await Promise.all(providers.map((p) => p.shutdown()));
    clearTimeout(watchdog);
    process.exit(0);
  } catch {
    process.exit(2);
  }
}
process.once("SIGTERM", shutdown);
process.once("SIGINT", shutdown);
module.exports = {
  unary,
  operation,
  log,
  stoppers,
  logger: {
    info: () => log("application.diagnostic", "diagnostic"),
    warn: () => log("application.diagnostic", "diagnostic"),
    error: () => log("application.diagnostic", "diagnostic"),
  },
};

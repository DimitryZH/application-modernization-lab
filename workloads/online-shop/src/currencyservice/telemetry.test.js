// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
const { test } = require("node:test");
const assert = require("node:assert/strict");
process.env.OTEL_SDK_DISABLED = "true";
const telemetry = require("./telemetry");
const { context, trace } = require("@opentelemetry/api");
const { EventEmitter } = require("node:events");
const grpc = require("@grpc/grpc-js");
test("concurrent callbacks retain their incoming context", async () => {
  const results = await Promise.all(
    Array.from(
      { length: 20 },
      (_, i) =>
        new Promise((resolve) => {
          const id = (i + 1).toString(16).padStart(32, "0");
          const call = new EventEmitter();
          call.metadata = new grpc.Metadata();
          call.metadata.set("traceparent", "00-" + id + "-0123456789abcdef-01");
          telemetry.unary("hipstershop.Test/Call", (call, callback) =>
            setTimeout(() => {
              assert.equal(trace.getSpanContext(context.active()).traceId, id);
              callback(null, { ok: true });
            }, i % 3),
          )(call, (err, value) => {
            assert.equal(err, null);
            resolve(value);
          });
        }),
    ),
  );
  assert.equal(results.length, 20);
});
test("business rejection survives instrumentation", () => {
  assert.throws(
    () =>
      telemetry.operation("payment.charge", () => {
        throw new Error("private-canary");
      }),
    /private-canary/,
  );
});

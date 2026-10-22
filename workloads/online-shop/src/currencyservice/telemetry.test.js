// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
const { test } = require("node:test");
const assert = require("node:assert/strict");
process.env.OTEL_SDK_DISABLED = "true";
const { metrics } = require("@opentelemetry/api");
const { MeterProvider, MetricReader } = require("@opentelemetry/sdk-metrics");
const { NodeTracerProvider } = require("@opentelemetry/sdk-trace-node");
const { SimpleSpanProcessor, InMemorySpanExporter } = require("@opentelemetry/sdk-trace-base");
class Reader extends MetricReader { async onForceFlush() {} async onShutdown() {} }
const reader = new Reader(); const mp = new MeterProvider({readers:[reader]});metrics.setGlobalMeterProvider(mp);
const exporter=new InMemorySpanExporter();const tp=new NodeTracerProvider({spanProcessors:[new SimpleSpanProcessor(exporter)]});
require("@opentelemetry/api").trace.setGlobalTracerProvider(tp);
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

test("failed RPC counters, span and completion log agree", async () => {
 const rows=[];const write=process.stdout.write;process.stdout.write=(s)=>{rows.push(JSON.parse(s));return true;};
 try {
  const call=new EventEmitter();call.metadata=new grpc.Metadata();
  telemetry.unary("hipstershop.Test/Failure",(c,done)=>done({code:13,message:"private-canary"}))(call,()=>{});
 } finally {process.stdout.write=write;}
 const result=await reader.collect();const points={};
 for(const scope of result.resourceMetrics.scopeMetrics) for(const m of scope.metrics) for(const p of m.dataPoints) if(p.attributes.operation==="hipstershop.Test/Failure") {
  assert.deepEqual(p.attributes,{operation:"hipstershop.Test/Failure",kind:"server",outcome:"error"});points[m.descriptor.name]=p.value;
 }
 assert.equal(points["online_shop.transport.requests"],1);assert.equal(points["online_shop.transport.errors"],1);assert.equal(points["online_shop.transport.duration"].count,1);
 const span=exporter.getFinishedSpans().find(s=>s.name==="hipstershop.Test/Failure");assert.equal(span.status.code,2);
 assert.equal(rows[0].outcome,"error");assert.equal(rows[0].span_id,span.spanContext().spanId);assert.ok(!JSON.stringify(rows).includes("private-canary"));
});

test("diagnostics retain severity, bounded category and active context", () => {
 const rows=[];const write=process.stdout.write;process.stdout.write=(s)=>{rows.push(JSON.parse(s));return true;};
 const sc={traceId:"0123456789abcdef0123456789abcdef",spanId:"0123456789abcdef",traceFlags:1};
 try {context.with(trace.setSpanContext(context.active(),sc),()=>{
   telemetry.logger.warn("private-canary");telemetry.logger.error(new Error("private-canary"));
   for(const category of ["startup","configuration","dependency"]) telemetry.diagnostic("ERROR",category);
 });} finally {process.stdout.write=write;}
 assert.deepEqual(rows.map(r=>r.severity),["WARN","ERROR","ERROR","ERROR","ERROR"]);
 assert.deepEqual(rows.map(r=>r.category),["application","application","startup","configuration","dependency"]);
 for(const row of rows){assert.equal(row.span_id,sc.spanId);assert.equal(row.event,row.category+".diagnostic");assert.ok(row["error.type"]);}
 assert.ok(!JSON.stringify(rows).includes("private-canary"));
});

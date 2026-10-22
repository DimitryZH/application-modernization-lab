// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	otelcodes "go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const telemetryService = "checkoutservice"

var telemetryTracer = otel.Tracer("online-shop." + telemetryService)
var requests, _ = otel.Meter("online-shop.checkoutservice").Int64Counter("online_shop.transport.requests", metric.WithUnit("{request}"))
var failures, _ = otel.Meter("online-shop.checkoutservice").Int64Counter("online_shop.transport.errors", metric.WithUnit("{request}"))
var durations, _ = otel.Meter("online-shop.checkoutservice").Float64Histogram("online_shop.transport.duration", metric.WithUnit("s"))
var business, _ = otel.Meter("online-shop.checkoutservice").Int64Counter("online_shop.business.operations", metric.WithUnit("{operation}"))
var stopMu sync.Mutex
var stopServers []func(context.Context)

func registerStop(f func(context.Context)) {
	stopMu.Lock()
	defer stopMu.Unlock()
	stopServers = append(stopServers, f)
}
func enabled() bool {
	if os.Getenv("OTEL_SDK_DISABLED") == "true" {
		return false
	}
	if v, ok := os.LookupEnv("ONLINE_SHOP_TELEMETRY_ENABLED"); ok {
		return v == "true" || v == "1"
	}
	return os.Getenv("ENABLE_TRACING") == "1" && os.Getenv("DISABLE_TRACING") == ""
}
func initTelemetry() {
	otel.SetTextMapPropagator(propagation.TraceContext{})
	var shutdowns []func(context.Context) error
	if enabled() {
		res := resource.NewWithAttributes("", attribute.String("service.name", telemetryService), attribute.String("service.namespace", "online-shop"), attribute.String("service.version", envOr("ONLINE_SHOP_VERSION", "development")), attribute.String("service.instance.id", envOr("HOSTNAME", telemetryService)), attribute.String("deployment.environment.name", envOr("ONLINE_SHOP_ENVIRONMENT", "local")))
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if os.Getenv("OTEL_TRACES_EXPORTER") != "none" {
			opts := []otlptracegrpc.Option{}
			if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" && os.Getenv("COLLECTOR_SERVICE_ADDR") != "" {
				opts = append(opts, otlptracegrpc.WithEndpoint(os.Getenv("COLLECTOR_SERVICE_ADDR")), otlptracegrpc.WithInsecure())
			}
			exp, err := otlptracegrpc.New(ctx, opts...)
			if err == nil {
				ratio := 0.1
				if os.Getenv("OTEL_TRACES_SAMPLER_ARG") == "1" {
					ratio = 1
				} else if v := os.Getenv("OTEL_TRACES_SAMPLER_ARG"); v != "" {
					if n, e := strconvParseRatio(v); e == nil {
						ratio = n
					}
				}
				tp := sdktrace.NewTracerProvider(sdktrace.WithResource(res), sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(ratio))), sdktrace.WithBatcher(exp, sdktrace.WithMaxQueueSize(512), sdktrace.WithMaxExportBatchSize(128), sdktrace.WithBatchTimeout(time.Second), sdktrace.WithExportTimeout(2*time.Second)))
				otel.SetTracerProvider(tp)
				shutdowns = append(shutdowns, tp.Shutdown)
			}
		}
		if os.Getenv("OTEL_METRICS_EXPORTER") != "none" {
			exp, err := otlpmetricgrpc.New(ctx)
			if err == nil {
				mp := sdkmetric.NewMeterProvider(sdkmetric.WithResource(res), sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exp, sdkmetric.WithInterval(metricInterval()), sdkmetric.WithTimeout(2*time.Second))), sdkmetric.WithView(sdkmetric.NewView(sdkmetric.Instrument{Kind: sdkmetric.InstrumentKindHistogram}, sdkmetric.Stream{Aggregation: sdkmetric.AggregationExplicitBucketHistogram{Boundaries: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10}}})))
				otel.SetMeterProvider(mp)
				shutdowns = append(shutdowns, mp.Shutdown)
			}
		}
	}
	telemetryTracer = otel.Tracer("online-shop." + telemetryService)
	meter := otel.Meter("online-shop." + telemetryService)
	requests, _ = meter.Int64Counter("online_shop.transport.requests", metric.WithUnit("{request}"))
	failures, _ = meter.Int64Counter("online_shop.transport.errors", metric.WithUnit("{request}"))
	durations, _ = meter.Float64Histogram("online_shop.transport.duration", metric.WithUnit("s"))
	business, _ = meter.Int64Counter("online_shop.business.operations", metric.WithUnit("{operation}"))
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-ch
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		stopMu.Lock()
		fs := append([]func(context.Context){}, stopServers...)
		stopMu.Unlock()
		for _, f := range fs {
			f(ctx)
		}
		for _, f := range shutdowns {
			_ = f(ctx)
		}
		os.Exit(0)
	}()
}
func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
func record(ctx context.Context, kind, method string, start time.Time, err error) {
	outcome := "ok"
	if err != nil {
		outcome = status.Code(err).String()
	}
	attrs := metric.WithAttributes(attribute.String("kind", kind), attribute.String("operation", method), attribute.String("outcome", outcome))
	if err != nil {
		failures.Add(ctx, 1, attrs)
	}
	requests.Add(ctx, 1, attrs)
	durations.Record(ctx, time.Since(start).Seconds(), attrs)
	if err != nil {
		s := trace.SpanFromContext(ctx)
		s.SetAttributes(attribute.String("error.type", outcome))
		s.SetStatus(otelcodes.Error, outcome)
	}
	category := "application"
	if kind == "client" {
		category = "dependency"
	}
	telemetryLogCategory(ctx, "request.completed", method, outcome, category)
}

type operationState struct{ outcome string }
type operationKey struct{}

func operation(ctx context.Context, name string) (context.Context, func()) {
	ctx, span := telemetryTracer.Start(ctx, name)
	state := &operationState{outcome: "ok"}
	ctx = context.WithValue(ctx, operationKey{}, state)
	return ctx, func() {
		business.Add(ctx, 1, metric.WithAttributes(attribute.String("operation", name), attribute.String("outcome", state.outcome)))
		telemetryLog(ctx, "operation.completed", name, state.outcome)
		span.End()
	}
}
func failOperation(ctx context.Context) {
	if state, ok := ctx.Value(operationKey{}).(*operationState); ok {
		state.outcome = "error"
	}
	trace.SpanFromContext(ctx).SetStatus(otelcodes.Error, "operation failed")
}
func degraded(ctx context.Context, name string) {
	trace.SpanFromContext(ctx).AddEvent(name)
	business.Add(ctx, 1, metric.WithAttributes(attribute.String("operation", name), attribute.String("outcome", "degraded")))
	telemetryLog(ctx, "operation.degraded", name, "degraded")
}
func telemetryLog(ctx context.Context, event, op, outcome string) {
	telemetryLogCategory(ctx, event, op, outcome, "application")
}
func telemetryLogCategory(ctx context.Context, event, op, outcome, category string) {
	sc := trace.SpanContextFromContext(ctx)
	row := map[string]any{"timestamp": time.Now().UTC().Format(time.RFC3339Nano), "severity": completionSeverity(outcome), "category": category, "message": event, "event": event, "operation": op, "outcome": outcome, "service.name": telemetryService, "service.namespace": "online-shop", "service.version": envOr("ONLINE_SHOP_VERSION", "development")}
	if outcome != "ok" && outcome != "miss" {
		row["error.type"] = outcome
	}
	if sc.IsValid() {
		row["trace_id"] = sc.TraceID().String()
		row["span_id"] = sc.SpanID().String()
		row["trace_flags"] = int(sc.TraceFlags())
	}
	b, _ := json.Marshal(row)
	os.Stdout.Write(append(b, '\n'))
}

func completionSeverity(outcome string) string {
	if outcome == "ok" || outcome == "miss" {
		return "INFO"
	}
	if outcome == "degraded" {
		return "WARN"
	}
	return "ERROR"
}

// Only explicit bounded categories cross the legacy logging boundary. Never serialize
// messages, exceptions or arbitrary fields. WithContext retains request correlation.
type safeFormatter struct{}

func (safeFormatter) Format(e *logrus.Entry) ([]byte, error) {
	category, _ := e.Data["telemetry.category"].(string)
	switch category {
	case "startup", "configuration", "dependency", "application":
	default:
		category = "application"
	}
	severity := strings.ToUpper(e.Level.String())
	if severity == "WARNING" {
		severity = "WARN"
	}
	if severity == "PANIC" {
		severity = "FATAL"
	}
	outcome := "ok"
	if e.Level <= logrus.ErrorLevel {
		outcome = category + "_failure"
	} else if e.Level == logrus.WarnLevel {
		outcome = "warning"
	}
	row := map[string]any{"timestamp": e.Time.UTC().Format(time.RFC3339Nano), "severity": severity, "category": category, "event": category + ".diagnostic", "message": category + ".diagnostic", "outcome": outcome, "service.name": telemetryService, "service.namespace": "online-shop", "service.version": envOr("ONLINE_SHOP_VERSION", "development")}
	if outcome != "ok" {
		row["error.type"] = outcome
	}
	if e.Context != nil {
		sc := trace.SpanContextFromContext(e.Context)
		if sc.IsValid() {
			row["trace_id"] = sc.TraceID().String()
			row["span_id"] = sc.SpanID().String()
			row["trace_flags"] = int(sc.TraceFlags())
		}
	}
	b, err := json.Marshal(row)
	return append(b, '\n'), err
}

type metadataCarrier metadata.MD

func (m metadataCarrier) Get(k string) string {
	v := metadata.MD(m).Get(k)
	if len(v) > 0 {
		return v[0]
	}
	return ""
}
func (m metadataCarrier) Set(k, v string) { metadata.MD(m).Set(k, v) }
func (m metadataCarrier) Keys() []string {
	out := []string{}
	for k := range m {
		out = append(out, k)
	}
	return out
}
func unaryServer(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
	if strings.HasPrefix(info.FullMethod, "/grpc.health.") {
		return handler(ctx, req)
	}
	md, _ := metadata.FromIncomingContext(ctx)
	ctx = otel.GetTextMapPropagator().Extract(ctx, metadataCarrier(md))
	ctx, s := telemetryTracer.Start(ctx, strings.TrimPrefix(info.FullMethod, "/"), trace.WithSpanKind(trace.SpanKindServer))
	defer s.End()
	start := time.Now()
	defer func() { record(ctx, "server", info.FullMethod, start, err) }()
	return handler(ctx, req)
}
func unaryClient(ctx context.Context, method string, req, reply any, cc *grpc.ClientConn, invoke grpc.UnaryInvoker, opts ...grpc.CallOption) (err error) {
	ctx, s := telemetryTracer.Start(ctx, strings.TrimPrefix(method, "/"), trace.WithSpanKind(trace.SpanKindClient))
	defer s.End()
	md, _ := metadata.FromOutgoingContext(ctx)
	md = md.Copy()
	otel.GetTextMapPropagator().Inject(ctx, metadataCarrier(md))
	ctx = metadata.NewOutgoingContext(ctx, md)
	start := time.Now()
	defer func() { record(ctx, "client", method, start, err) }()
	return invoke(ctx, method, req, reply, cc, opts...)
}

type httpStatus struct {
	http.ResponseWriter
	status int
}

func (w *httpStatus) WriteHeader(n int) {
	if w.status == 0 {
		w.status = n
		w.ResponseWriter.WriteHeader(n)
	}
}
func (w *httpStatus) Write(b []byte) (int, error) {
	if w.status == 0 {
		w.WriteHeader(200)
	}
	return w.ResponseWriter.Write(b)
}
func httpTelemetry(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/_healthz" || strings.HasPrefix(r.URL.Path, "/static/") {
			next.ServeHTTP(w, r)
			return
		}
		route := safeRoute(r.URL.Path)
		ctx := otel.GetTextMapPropagator().Extract(r.Context(), propagation.HeaderCarrier(r.Header))
		ctx, s := telemetryTracer.Start(ctx, r.Method+" "+route, trace.WithSpanKind(trace.SpanKindServer))
		defer s.End()
		rec := &httpStatus{ResponseWriter: w}
		start := time.Now()
		next.ServeHTTP(rec, r.WithContext(ctx))
		if rec.status == 0 {
			rec.status = http.StatusOK
		}
		var err error
		if rec.status >= 500 {
			err = status.Error(codes.Internal, "http failure")
		}
		s.SetAttributes(attribute.Int("http.response.status_code", rec.status), attribute.String("http.route", route))
		record(ctx, "server", r.Method+" "+route, start, err)
	})
}
func safeRoute(path string) string {
	for _, r := range []string{"/", "/cart", "/cart/empty", "/cart/checkout", "/setCurrency", "/logout", "/assistant", "/bot", "/robots.txt"} {
		if path == r {
			return r
		}
	}
	if strings.HasPrefix(path, "/product/") {
		return "/product/{id}"
	}
	if strings.HasPrefix(path, "/product-meta/") {
		return "/product-meta/{ids}"
	}
	return "unmatched"
}
func telemetryHTTP(ctx context.Context, req *http.Request, dependency string) (*http.Response, error) {
	ctx, s := telemetryTracer.Start(ctx, "HTTP "+dependency, trace.WithSpanKind(trace.SpanKindClient))
	defer s.End()
	req = req.WithContext(ctx)
	otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(req.Header))
	start := time.Now()
	resp, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	record(ctx, "client", dependency, start, err)
	return resp, err
}

func strconvParseRatio(v string) (float64, error) {
	n, e := strconv.ParseFloat(v, 64)
	if n < 0 || n > 1 {
		return .1, fmt.Errorf("invalid sampling ratio")
	}
	return n, e
}

func metricInterval() time.Duration {
	n, err := strconv.Atoi(envOr("OTEL_METRIC_EXPORT_INTERVAL", "10000"))
	if err != nil || n < 1000 {
		n = 10000
	}
	return time.Duration(n) * time.Millisecond
}

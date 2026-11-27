// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
package main

import (
	"context"
	"encoding/json"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	otelcodes "go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func TestManualRPCParentAndInjection(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	defer provider.Shutdown(context.Background())
	previous := telemetryTracer
	telemetryTracer = provider.Tracer("test")
	defer func() { telemetryTracer = previous }()
	otel.SetTextMapPropagator(propagation.TraceContext{})
	parent := "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs("traceparent", parent))
	_, err := unaryServer(ctx, nil, &grpc.UnaryServerInfo{FullMethod: "/hipstershop.Test/Call"}, func(ctx context.Context, _ any) (any, error) {
		current := trace.SpanContextFromContext(ctx)
		if current.TraceID().String() != "0123456789abcdef0123456789abcdef" {
			t.Fatal("lost parent")
		}
		return nil, unaryClient(ctx, "/hipstershop.Test/Child", nil, nil, nil, func(ctx context.Context, _ string, _, _ any, _ *grpc.ClientConn, _ ...grpc.CallOption) error {
			md, _ := metadata.FromOutgoingContext(ctx)
			if len(md.Get("traceparent")) != 1 {
				t.Fatal("missing propagation")
			}
			return nil
		})
	})
	if err != nil {
		t.Fatal(err)
	}
	spans := exporter.GetSpans()
	if len(spans) != 2 {
		t.Fatalf("want client and server, got %d", len(spans))
	}
	if spans[0].Parent.SpanID() != spans[1].SpanContext.SpanID() {
		t.Fatal("client not a child")
	}
}
func TestDiagnosticsNeverSerializeSensitiveValues(t *testing.T) {
	row, err := (safeFormatter{}).Format(&logrus.Entry{Time: time.Now(), Level: logrus.ErrorLevel, Message: "secret-canary", Data: logrus.Fields{"email": "secret-canary"}})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(row), "secret-canary") {
		t.Fatal("sensitive diagnostic")
	}
	var parsed map[string]any
	if json.Unmarshal(row, &parsed) != nil {
		t.Fatal("not JSON")
	}
}
func TestDisableOverridesEnable(t *testing.T) {
	t.Setenv("ONLINE_SHOP_TELEMETRY_ENABLED", "true")
	t.Setenv("OTEL_SDK_DISABLED", "true")
	if enabled() {
		t.Fatal("disable ignored")
	}
}

func TestHTTPUserInputCannotCreateSpanOrMetricDimensions(t *testing.T) {
	exporter := tracetest.NewInMemoryExporter()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
	defer provider.Shutdown(context.Background())
	previous := telemetryTracer
	telemetryTracer = provider.Tracer("test")
	defer func() { telemetryTracer = previous }()
	handler := httpTelemetry(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("UNTRUSTED-1234", "/product/private-canary", nil))
	spans := exporter.GetSpans()
	if len(spans) != 1 || spans[0].Name != "OTHER /product/{id}" {
		t.Fatalf("unbounded span name: %v", spans)
	}
	for _, attr := range spans[0].Attributes {
		if strings.Contains(attr.Value.AsString(), "private-canary") {
			t.Fatal("raw path captured")
		}
	}
}

func TestHTTPOutcomeAgreement(t *testing.T) {
	for _, tc := range []struct {
		name    string
		code    int
		server  bool
		outcome string
	}{
		{"client503", 503, false, "http_5xx"}, {"client404", 404, false, "http_4xx"},
		{"transport", 0, false, "transport_error"}, {"server503", 503, true, "http_5xx"},
		{"server404", 404, true, "ok"}, {"client200", 200, false, "ok"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			reader := sdkmetric.NewManualReader()
			mp := sdkmetric.NewMeterProvider(sdkmetric.WithReader(reader))
			defer mp.Shutdown(context.Background())
			meter := mp.Meter("test")
			oldR, oldE, oldD := requests, failures, durations
			defer func() { requests, failures, durations = oldR, oldE, oldD }()
			requests, _ = meter.Int64Counter("requests")
			failures, _ = meter.Int64Counter("errors")
			durations, _ = meter.Float64Histogram("duration")
			exporter := tracetest.NewInMemoryExporter()
			tp := sdktrace.NewTracerProvider(sdktrace.WithSyncer(exporter))
			defer tp.Shutdown(context.Background())
			oldT := telemetryTracer
			telemetryTracer = tp.Tracer("test")
			defer func() { telemetryTracer = oldT }()
			oldOut := os.Stdout
			read, write, _ := os.Pipe()
			os.Stdout = write
			defer func() { os.Stdout = oldOut }()
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(tc.code) })
			if tc.server {
				httpTelemetry(handler).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/", nil))
			} else {
				server := httptest.NewServer(handler)
				if tc.code == 0 {
					server.Close()
				} else {
					defer server.Close()
				}
				req, _ := http.NewRequest("GET", server.URL, nil)
				resp, err := telemetryHTTP(context.Background(), req, "test")
				if tc.code == 0 && err == nil {
					t.Fatal("lost transport error")
				}
				if tc.code != 0 && (err != nil || resp.StatusCode != tc.code) {
					t.Fatal("changed response")
				}
				if resp != nil {
					resp.Body.Close()
				}
			}
			write.Close()
			os.Stdout = oldOut
			raw, _ := io.ReadAll(read)
			read.Close()
			var row map[string]any
			if json.Unmarshal(raw, &row) != nil || row["outcome"] != tc.outcome {
				t.Fatalf("log %s", raw)
			}
			spans := exporter.GetSpans()
			if len(spans) != 1 || (spans[0].Status.Code == otelcodes.Error) != (tc.outcome != "ok") {
				t.Fatalf("span mismatch %v", spans)
			}
			if row["span_id"] != spans[0].SpanContext.SpanID().String() {
				t.Fatal("log correlation")
			}
			var rm metricdata.ResourceMetrics
			if reader.Collect(context.Background(), &rm) != nil {
				t.Fatal("collect")
			}
			values := map[string]int64{}
			for _, scope := range rm.ScopeMetrics {
				for _, m := range scope.Metrics {
					check := func(a attribute.Set) {
						if a.Len() != 3 {
							t.Fatal(a)
						}
						v, _ := a.Value("outcome")
						if v.AsString() != tc.outcome {
							t.Fatal(a)
						}
						k, _ := a.Value("kind")
						want := "client"
						if tc.server {
							want = "server"
						}
						if k.AsString() != want {
							t.Fatal(a)
						}
					}
					switch data := m.Data.(type) {
					case metricdata.Sum[int64]:
						for _, p := range data.DataPoints {
							check(p.Attributes)
							values[m.Name] += p.Value
						}
					case metricdata.Histogram[float64]:
						for _, p := range data.DataPoints {
							check(p.Attributes)
							values[m.Name] += int64(p.Count)
						}
					}
				}
			}
			wantErrors := int64(0)
			if tc.outcome != "ok" {
				wantErrors = 1
			}
			if values["requests"] != 1 || values["duration"] != 1 || values["errors"] != wantErrors {
				t.Fatal(values)
			}
		})
	}
}

func TestDiagnosticSeverityCategoryContext(t *testing.T) {
	sc := trace.NewSpanContext(trace.SpanContextConfig{TraceID: trace.TraceID{1}, SpanID: trace.SpanID{2}})
	for _, level := range []logrus.Level{logrus.WarnLevel, logrus.ErrorLevel, logrus.FatalLevel} {
		row, err := (safeFormatter{}).Format(&logrus.Entry{Time: time.Now(), Level: level, Context: trace.ContextWithSpanContext(context.Background(), sc), Message: "private-canary", Data: logrus.Fields{"telemetry.category": "dependency", "error": "private-canary"}})
		if err != nil || strings.Contains(string(row), "private-canary") {
			t.Fatal(string(row), err)
		}
		var parsed map[string]any
		json.Unmarshal(row, &parsed)
		want := "WARN"
		if level == logrus.ErrorLevel {
			want = "ERROR"
		}
		if level == logrus.FatalLevel {
			want = "FATAL"
		}
		if parsed["severity"] != want || parsed["category"] != "dependency" || parsed["span_id"] != sc.SpanID().String() || parsed["error.type"] == nil {
			t.Fatal(parsed)
		}
	}
}

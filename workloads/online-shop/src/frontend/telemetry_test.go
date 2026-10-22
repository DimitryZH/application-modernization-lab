// Copyright 2026 Online Shop contributors. SPDX-License-Identifier: Apache-2.0
package main

import (
	"context"
	"encoding/json"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"net/http"
	"net/http/httptest"
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

// Copyright 2026 Trail Supply contributors. SPDX-License-Identifier: Apache-2.0
package main

import (
	"bytes"
	"strings"
	"testing"

	pb "github.com/GoogleCloudPlatform/microservices-demo/src/frontend/genproto"
)

// Exercise real templates with their handler-shaped data, including prefixed
// routes and optional states. A parse-only check cannot catch execution errors.
func TestStorefrontTemplates(t *testing.T) {
	product := &pb.Product{Id: "OLJCESPC7Z", Name: "Summit 45L Backpack", Picture: "/static/img/products/summit-45l-backpack.jpg", Description: "A trail companion."}
	price := &pb.Money{CurrencyCode: "USD", Units: 129}
	view := struct {
		Item  *pb.Product
		Price *pb.Money
	}{product, price}
	items := []struct {
		Item     *pb.Product
		Price    *pb.Money
		Quantity int32
	}{{product, price, 1}}
	for _, name := range []string{"home", "product", "cart", "order", "error", "assistant"} {
		for _, prefix := range []string{"", "/trail"} {
			t.Run(name+prefix, func(t *testing.T) {
				data := map[string]interface{}{
					"baseUrl": prefix, "currentYear": 2026, "user_currency": "USD",
					"show_currency": true, "currencies": []string{"USD", "CAD"},
					"products": []interface{}{view}, "product": view, "items": items,
					"cart_size": 1, "shipping_cost": price, "total_cost": price,
					"total_paid": price, "expiration_years": []int{2026, 2027},
					"order": &pb.OrderResult{OrderId: "demo-order", ShippingTrackingId: "demo-tracking"},
					"status_code": 422, "status": "Unprocessable Entity", "error": "Check the demo form.",
					"recommendations": []*pb.Product{product},
					"ad": &pb.Ad{RedirectUrl: "/product/OLJCESPC7Z", Text: "Explore the Summit 45L Backpack."},
					"frontendMessage": "Demo environment", "platform_name": "local",
					"assistant_enabled": true, "is_cymbal_brand": false,
				}
				var rendered bytes.Buffer
				if err := templates.ExecuteTemplate(&rendered, name, data); err != nil {
					t.Fatal(err)
				}
				html := rendered.String()
				for _, expected := range []string{"Trail Supply", "id=\"main-content\"", prefix + "/#shop", prefix + "/static/styles/styles.css"} {
					if !strings.Contains(html, expected) {
						t.Errorf("missing %q", expected)
					}
				}
				if strings.Count(html, "</html>") != 1 || strings.Count(html, "<footer ") != 1 {
					t.Fatal("expected one complete document and footer")
				}
				if strings.Contains(html, "fonts.googleapis.com") || strings.Contains(html, "stackpath.bootstrapcdn.com") {
					t.Fatal("unexpected external presentation dependency")
				}
				if prefix != "" && (strings.Contains(html, `src="/static/`) || strings.Contains(html, `href="/product/`)) {
					t.Fatal("asset or product route escaped BASE_URL")
				}
			})
		}
	}
}

func TestEmptyCartAndLegacyFaviconSwitch(t *testing.T) {
	data := map[string]interface{}{"baseUrl": "/trail", "items": []interface{}{}, "currentYear": 2026, "is_cymbal_brand": true}
	var rendered bytes.Buffer
	if err := templates.ExecuteTemplate(&rendered, "cart", data); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Your shopping cart is empty", "/trail/static/favicon-cymbal.ico"} {
		if !strings.Contains(rendered.String(), expected) {
			t.Errorf("missing %q", expected)
		}
	}
}

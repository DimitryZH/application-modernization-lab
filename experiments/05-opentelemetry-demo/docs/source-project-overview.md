# Source Project Overview

## Source Identity

- Project: OpenTelemetry Demo, also known as Astronomy Shop
- Official repository: `https://github.com/open-telemetry/opentelemetry-demo.git`
- Validated commit: `b5320139de38b789654a9653d5c4fda441b5cb8f`
- Validated branch state: clean `main` tracking `origin/main`
- Runtime clone: `~/experiment-05-opentelemetry-demo-source` on the existing DevBox

The upstream source is not vendored into this experiment repository. Stage A used a pinned runtime clone and did not modify it.

## Application Shape

The full deployment combines a polyglot commerce application with supporting data, messaging, feature-flag, load-generation, and observability services.

Application services:

- accounting
- ad
- cart
- checkout
- currency
- email
- frontend
- fraud-detection
- image-provider
- llm
- payment
- product-catalog
- product-reviews
- quote
- recommendation
- shipping

Platform and support services:

- astronomy-db
- flagd
- flagd-ui
- frontend-proxy
- kafka
- load-generator
- telemetry-docs
- valkey-cart

Observability services:

- grafana
- jaeger
- opensearch
- otel-collector
- prometheus

## Source Characteristics Relevant to Migration

- The application is intentionally polyglot and uses both automatic and manual OpenTelemetry instrumentation.
- The full deployment is assembled from multiple Compose files rather than one standalone file.
- Most application images are prebuilt upstream images; migration must preserve their runtime contracts rather than rebuild their implementation.
- Startup behavior depends on health checks, restart policies, and delayed dependency readiness.
- The deployment includes intentional failure controls and may produce errors even when the core storefront remains available.
- The source includes local environment files. Their values were not copied into tracked Experiment 05 artifacts.

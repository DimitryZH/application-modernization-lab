# AKS Store Demo Compose Validation Report

Generated: 2026-07-30T22:45:51Z UTC

- Pinned source manifest verified for upstream commit 7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5.
- Rendered Compose configuration has the nine approved non-AI services, no fixed container names, and loopback-only UI host bindings.
- Runtime validation artifacts are ignored and untracked.
- Docker labels identify only the expected aks-store-demo-compose Compose resources.
- store-front health reachable at http://127.0.0.1:8080/health.
- store-admin health reachable at http://127.0.0.1:8081/health.
- store-front product proxy reachable at http://127.0.0.1:8080/api/products.
- store-admin product proxy reachable at http://127.0.0.1:8081/api/products.
- Product workflow returned 10 seeded products through the storefront proxy.
- RabbitMQ queue 'orders' exists in the Experiment 08 rabbitmq container.
- Paused virtual-customer and virtual-worker during unique current-run evidence collection.
- Submitted unique current-run order for aml08-20260730224703-105128; makeline assigned orderId 31534 and stored it in DocumentDB.
- makeline after restart reachable at http://127.0.0.1:8081/api/makeline/order/fetch.
- Makeline-service restart preserved access to current-run order 31534.

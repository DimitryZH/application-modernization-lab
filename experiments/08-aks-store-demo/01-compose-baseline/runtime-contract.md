# Runtime Contract

Compose project: `aks-store-demo-compose` by default.

Default endpoints:

- Storefront: `http://127.0.0.1:8080`
- Admin: `http://127.0.0.1:8081`

Required internal contracts:

- RabbitMQ credentials: `username` / `password`; queue `orders`.
- Order service publishes to host `rabbitmq`, port `5672`.
- Makeline consumes `amqp://rabbitmq:5672` and address `/queues/orders`.
- Makeline stores orders in DocumentDB using `mongodb://documentdb:10260/?tls=true&tlsAllowInvalidCertificates=true`, database `orderdb`, collection `orders`, auth source `orderdb`.
- Product service keeps `AI_SERVICE_URL=http://ai-service:5001/`; default validation classifies AI routes as optional expected-unavailable behavior when the `ai` profile is not running.
- Virtual workload services remain in the default service set with low documented rates. The validator pauses them during unique current-run order evidence collection, then restores them.

Local differences from the upstream `docker-compose.yml` are approved for Experiment 08A isolation and safety:

- no fixed `container_name` values;
- loopback-only UI host bindings;
- backend endpoints internal by default;
- `ai-service` moved behind optional profile `ai`;
- deterministic workload rate of `1` order/hour for both virtual services;
- UI health checks target the nginx listener ports `8080` and `8081`.
- DocumentDB health accepts current OpenSSL TLS output containing either `CONNECTED` or `CONNECTION ESTABLISHED`.
- Product-service container healthcheck is omitted because the upstream Debian runner does not include `wget`; product readiness is validated through `/health` and product data via the storefront and admin HTTP proxies.

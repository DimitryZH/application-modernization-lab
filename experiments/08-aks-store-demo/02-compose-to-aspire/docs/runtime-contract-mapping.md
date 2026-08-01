# Runtime Contract Mapping

Experiment 08B preserves the accepted Experiment 08A runtime contract:

- RabbitMQ connection values stay on `rabbitmq:5672` with username/password `username`/`password` and queue `orders`.
- DocumentDB connection stays on `mongodb://documentdb:10260/?tls=true&tlsAllowInvalidCertificates=true`, database `orderdb`, collection `orders`, username/password `username`/`password`.
- Storefront and admin frontends remain the only host-visible services.
- Product, order, makeline, broker, and database services remain internal.
- `virtual-customer` and `virtual-worker` remain present at `ORDERS_PER_HOUR=1`, but validation pauses them while collecting current-run order evidence.
- `ai-service` is not part of the default runtime or PASS criteria.

Aspire-generated Docker container names may differ from Compose names. The application-visible service names are preserved through Aspire resource names and DCP network aliases, and the validator proves the current resources are selected by Aspire/DCP labels rather than image digests or Compose labels.

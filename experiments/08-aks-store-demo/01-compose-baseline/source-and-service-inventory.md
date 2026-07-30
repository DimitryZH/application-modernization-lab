# Source and Service Inventory

Default required services:

| Service | Role | Source or Image | Host Exposure | State |
| --- | --- | --- | --- | --- |
| `documentdb` | Local DocumentDB-compatible MongoDB endpoint | `ghcr.io/documentdb/documentdb/documentdb-local:pg17-0.112.0` | Internal only | Container writable layer |
| `rabbitmq` | AMQP broker for queue `orders` | `rabbitmq:4.3.2-management-alpine` | Internal only | Container writable layer |
| `order-service` | Accepts orders and publishes to RabbitMQ | `src/order-service` | Internal only | Stateless |
| `makeline-service` | Consumes queue messages and stores orders | `src/makeline-service` | Internal only | Uses DocumentDB |
| `product-service` | Product catalog and optional AI proxy | `src/product-service` | Internal only | In-memory seeded catalog |
| `store-front` | Customer storefront | `src/store-front` | `127.0.0.1:8080` | Browser cart only |
| `store-admin` | Admin products and order queue UI | `src/store-admin` | `127.0.0.1:8081` | Reads backend state |
| `virtual-customer` | Background order generator | `src/virtual-customer` | None | Runtime workload |
| `virtual-worker` | Background order processor | `src/virtual-worker` | None | Runtime workload |

Optional service:

| Service | Role | Default Treatment |
| --- | --- | --- |
| `ai-service` | OpenAI-compatible text/image backend | Behind Compose profile `ai`; excluded from default PASS criteria |

The local Compose adaptation removes fixed upstream `container_name` values so Compose project labels and service labels are the runtime identity. Backend ports are not published by default. Application-visible service DNS names remain unchanged.

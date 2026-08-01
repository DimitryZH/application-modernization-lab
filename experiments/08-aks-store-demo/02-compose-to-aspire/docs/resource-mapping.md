# Resource Mapping

| Service | Aspire resource | Source | Endpoint exposure | Required environment |
| --- | --- | --- | --- | --- |
| `documentdb` | `documentdb` | `ghcr.io/documentdb/documentdb/documentdb-local:pg17-0.112.0` | Internal `10260` only | command `--username username --password password` |
| `rabbitmq` | `rabbitmq` | `rabbitmq:4.3.2-management-alpine` | Internal `5672`, `15672` only | `RABBITMQ_DEFAULT_USER=username`, `RABBITMQ_DEFAULT_PASS=password` |
| `order-service` | `order-service` | `../01-compose-baseline/src/order-service/Dockerfile` | Internal `3000` only | Queue host, port, credentials, and `orders` queue |
| `makeline-service` | `makeline-service` | `../01-compose-baseline/src/makeline-service/Dockerfile` | Internal `3001` only | RabbitMQ URI plus DocumentDB TLS URI, DB, collection, credentials |
| `product-service` | `product-service` | `../01-compose-baseline/src/product-service/Dockerfile` | Internal `3002` only | `AI_SERVICE_URL=http://ai-service:5001/` |
| `store-front` | `store-front` | `../01-compose-baseline/src/store-front/Dockerfile` | `127.0.0.1:8080` | Nginx config uses internal service names |
| `store-admin` | `store-admin` | `../01-compose-baseline/src/store-admin/Dockerfile` | `127.0.0.1:8081` | Nginx config uses internal service names |
| `virtual-customer` | `virtual-customer` | `../01-compose-baseline/src/virtual-customer/Dockerfile` | None | `ORDER_SERVICE_URL=http://order-service:3000/`, `ORDERS_PER_HOUR=1` |
| `virtual-worker` | `virtual-worker` | `../01-compose-baseline/src/virtual-worker/Dockerfile` | None | `MAKELINE_SERVICE_URL=http://makeline-service:3001`, `ORDERS_PER_HOUR=1` |

All application containers are Aspire container resources built from the accepted Experiment 08A source snapshot. No application project references or ServiceDefaults are used.

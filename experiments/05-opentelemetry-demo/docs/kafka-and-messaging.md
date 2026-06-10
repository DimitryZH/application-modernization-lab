# Kafka and Messaging

## Architecture

Kafka is added by `compose.full.yaml` and runs as a single-broker KRaft deployment.

Messaging path:

```text
checkout
  -> orders topic
  -> accounting
  -> fraud-detection
```

The checkout service conditionally publishes order events when its Kafka address is configured. Accounting and fraud-detection are Kafka consumers.

## Broker Configuration Characteristics

- single broker;
- KRaft controller mode;
- broker listener on port 9092;
- controller listener on port 9093;
- topic auto-creation enabled;
- replication factor of one;
- Java agent and JMX instrumentation enabled.

The OpenTelemetry Collector full configuration includes a Kafka metrics receiver that observes brokers, topics, and consumers.

## Failure Controls

The `kafkaQueueProblems` feature flag can intentionally simulate queue overload or consumer lag. Its default variant was `off` during Stage A.

## Stage A Evidence

- Kafka reached its configured healthy state.
- Accounting connected to `kafka:9092`.
- Accounting initially reported that the `orders` topic was unavailable, then consumed generated order events after topic creation.
- Kafka reported temporary telemetry export failures while the Collector was not yet running.
- Fraud-detection did not remain stable because of an upstream flagd resolver error; this limits full validation of the second consumer.

## Migration Implications

- Aspire ordering must wait for real broker readiness, not only process start.
- Topic auto-creation is part of the observed baseline and must be preserved or replaced deliberately.
- KRaft listeners and advertised addresses must remain valid inside the Aspire-managed network.
- Kafka observability and consumer behavior must be validated independently from storefront endpoint success.

# Image Pinning Strategy

## Purpose

Prevent image drift from invalidating the functional-equivalence comparison
between the Stage A Docker Compose baseline and the Aspire deployment.

## Pinning Policy

- Preserve the resolved Stage A image as the initial migration target.
- Replace floating application tags such as `latest-accounting` with immutable
  digest references before the corresponding resource is implemented.
- Preserve already versioned image tags, such as PostgreSQL `17.8`, while also
  recording their resolved digest.
- Use the same immutable digest in Compose comparison records and AppHost
  declarations whenever Aspire supports digest-qualified image references.
- Treat any deliberate image version change as a documented migration
  deviation that requires separate validation.

## Digest Inventory

The implementation will maintain a tracked image inventory in:

```text
experiments/05-opentelemetry-demo/aspire/image-lock.json
```

The inventory will be introduced before the first container resource in Stage
C.2. Each entry must record:

- Compose service name;
- image repository;
- Stage A resolved tag;
- immutable digest;
- image ID when available;
- capture date;
- source evidence or capture command;
- any intentional Aspire deviation.

The inventory must contain all images used by the resolved 29-service
deployment. AppHost image declarations and the inventory will be reviewed
together.

## Preserving the Stage A Baseline

The Stage A baseline used the resolved four-layer Compose deployment at
upstream commit `b5320139de38b789654a9653d5c4fda441b5cb8f`. Its image identity
must be captured from the existing Stage A environment or equivalent retained
evidence before pulling or selecting replacements.

Recommended evidence commands for the later image-inventory step are:

```bash
docker compose images --format json
docker image inspect <image-reference>
```

If an exact Stage A digest cannot be recovered, the chosen replacement digest
must be documented as a known equivalence limitation before runtime
validation. Floating tags alone are not acceptable implementation pins.

## Update Rules

- Do not update pinned digests incidentally.
- Review digest changes as explicit experiment changes.
- Record why a digest changed and which validation stages must be repeated.
- Keep registry credentials and other sensitive values out of the inventory.

## Stage C.2 State

The initial inventory contains the four Stage C.2 infrastructure images:
`astronomy-db`, `valkey-cart`, `flagd`, and `llm`. Their digests and image IDs
were captured from the running Stage A containers before Stage C.2 resources
were started. AppHost declarations preserve the readable source tags and pin
the captured digests with `WithImageSHA256`.

## Stage C.3 State

The inventory now contains six images. Stage C.3 adds the Stage A `kafka` and
`accounting` image digests and image IDs. The Kafka entry preserves the exact
instrumented demo image rather than substituting a different broker image or
Aspire integration. The accounting entry preserves the exact consumer image;
its PostgreSQL password remains an Aspire secret expression and is not stored
in the image inventory.

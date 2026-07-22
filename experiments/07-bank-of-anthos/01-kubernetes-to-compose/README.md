# Experiment 07A: Bank of Anthos Kubernetes to Docker Compose

This experiment creates a local Docker Compose baseline for Bank of Anthos from upstream commit `1e40564f9ff572a28281198903e19da93e506770`.

The upstream Kubernetes manifests under `upstream/kubernetes-manifests/` are the authoritative deployment reference. Application source is not copied or modified; the Compose baseline uses the immutable upstream images pinned in those manifests.

## Topology

Required services:

| Service | Role | Image |
| --- | --- | --- |
| `frontend` | Python web UI and gateway | `frontend:v0.6.10@sha256:076294ce717309f711743fa3b72a9809c7f156edf1c4fa58505fd9f436d65345` |
| `userservice` | Demo user authentication and JWT signing | `userservice:v0.6.10@sha256:d8c4412edc46ab105000f721788b73301651cc43b19cee7e7302739f81882dcc` |
| `contacts` | User contact data | `contacts:v0.6.10@sha256:90d47594270e64f8dafa6da52c89ff70c2483cca0821dff2cc38b1450ac7a6b9` |
| `ledgerwriter` | Transaction validation and writes | `ledgerwriter:v0.6.10@sha256:eae37de0d9b28fec7534c1ea860868c87279b0a85b405f8fd66c3d7734e3e42f` |
| `balancereader` | Balance cache from ledger database | `balancereader:v0.6.10@sha256:feae443c650786c253bbfa3447d0902dd1689122c13962f97ccc37068d73733b` |
| `transactionhistory` | Transaction history cache from ledger database | `transactionhistory:v0.6.10@sha256:109cdad9c29a46af2708574ac4635dd73afa30cc020a4fef0266abcde87db744` |
| `accounts-db` | PostgreSQL users and contacts store | `accounts-db:v0.6.10@sha256:d95c4094c75f69069b915ef3adc99a8f95e43077885140cdeeb90d807ea74eff` |
| `ledger-db` | PostgreSQL append-only transaction ledger | `ledger-db:v0.6.10@sha256:891cb7afe34f358ce7ed7002a1923b25e113b30bca44fecb10cc8b116d665a03` |

The optional `loadgenerator` service is behind the `loadgen` profile and is disabled by default.

## Runtime Model

The Compose project name is `bank-of-anthos-compose`. Internal service names match the Kubernetes service DNS names. Only the frontend is published, and it is bound to loopback:

```bash
http://127.0.0.1:8080
```

The two PostgreSQL stores use named volumes:

| Volume | Mount |
| --- | --- |
| `accounts-db-data` | `/var/lib/postgresql/data` in `accounts-db` |
| `ledger-db-data` | `/var/lib/postgresql/data` in `ledger-db` |

Kubernetes uses ephemeral development database storage; Compose intentionally uses named volumes so persistence can be validated across a controlled restart.

## Local Secrets

Bank of Anthos requires an RSA private key for `userservice` and the matching public key for the frontend and ledger/account services. Generate local keys before startup:

```bash
./scripts/generate-jwt-keys.sh
```

Keys are written under `.local/jwt/`, ignored by git, and mounted read-only into containers. Do not commit generated keys, cookies, logs, dumps, or local evidence.

## Startup

From this directory:

```bash
./scripts/generate-jwt-keys.sh
docker compose up -d
```

The demo login is local-only:

```text
username: testuser
password: bankofanthos
```

## Validation

Run the native validator from this directory:

```bash
./scripts/validate-compose.sh
```

The validator starts the deterministic Compose project, verifies exact Compose service identities using Docker labels, waits for service readiness through the Compose network, logs in through the frontend, submits a representative deposit, verifies database persistence, restarts without deleting volumes, verifies persistence again, checks that validation fails when `ledger-db` is stopped, and shuts the stack down.

The validator exits non-zero if required services are missing, stopped, mislabeled, unreachable, non-functional, or if generated local secret material is tracked.

## Cleanup and Reset

Normal shutdown:

```bash
docker compose down
```

Full reset, including database state and generated local JWT material:

```bash
docker compose down -v
rm -rf .local
```

## Known Differences

- Local Compose disables `ENABLE_TRACING` because the Kubernetes deployment expects Google Cloud tracing/runtime integration that is not present locally.
- Local Compose disables Java `ENABLE_METRICS` because the pinned images initialize the Stackdriver meter registry when metrics are enabled, which requires GCP runtime metadata that is unavailable in local Compose. The Java containers also use Kubernetes-like local hostnames because the pinned metrics registry setup parses `HOSTNAME` as a pod-style name during startup. Java processor metrics and JVM container support are disabled for this local runtime because this host exposes cgroup data differently than the pinned JDK expects.
- Compose does not reproduce Kubernetes ServiceAccounts, GKE metadata, LoadBalancer behavior, Istio annotations, scheduling, resource policy, or exact probe timing.
- Database credentials are upstream demo-local defaults and are not production credentials.
- The optional load generator is disabled by default because it mutates ledger state continuously and would make deterministic validation harder.

## Rollback

Rollback the repository by reverting or removing this experiment directory from the implementation branch. Runtime rollback is `docker compose down`; full local reset is `docker compose down -v` plus removal of `.local`.

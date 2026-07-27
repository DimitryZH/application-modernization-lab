# Validation Results

## Source

- Upstream repository: `https://github.com/GoogleCloudPlatform/bank-of-anthos`
- Pinned commit: `1e40564f9ff572a28281198903e19da93e506770`
- Reference manifests: `upstream/kubernetes-manifests/`

## Commands

```bash
cd experiments/07-bank-of-anthos/01-kubernetes-to-compose
./scripts/generate-jwt-keys.sh
./scripts/validate-compose.sh
```

## Expected Evidence

The committed validator records the following evidence during execution:

| Area | Evidence |
| --- | --- |
| Service identity | Exact services under Compose project label `bank-of-anthos-compose`: `accounts-db`, `ledger-db`, `userservice`, `contacts`, `balancereader`, `transactionhistory`, `ledgerwriter`, `frontend`. |
| Readiness | Database health checks and HTTP `/ready` checks for application services from inside the Compose network. |
| Frontend reachability | `GET http://127.0.0.1:8080/ready`. |
| Authentication | `POST /login` with local demo user `testuser` and password `bankofanthos`, retaining a cookie jar under ignored `.local/validation/`. |
| Account data | Authenticated `GET /home` contains account, balance, transaction, deposit, or payment content. |
| Transaction flow | Authenticated `POST /deposit` with a unique request UUID and amount `$12.34`. |
| Database persistence | `ledger-db` transaction count for the controlled deposit increases and remains stable after `docker compose down` followed by `docker compose up -d`. |
| Negative dependency | Validation intentionally fails while required service `ledger-db` is stopped. |
| Cleanup | Validator finishes with `docker compose down --remove-orphans`; full reset is documented with `docker compose down -v`. |
| Secret handling | Generated JWT material under `.local/jwt/` is ignored and checked as untracked. |

## Local Result

Status: passed on 2026-07-22 UTC.

Runtime summary:

- Docker 29.6.1
- Docker Compose v5.3.1

Observed validator evidence:

- Generated local JWT key pair under ignored `.local/jwt/`; validator confirmed generated material is untracked.
- Started Compose project `bank-of-anthos-compose` from fresh named volumes.
- Verified exact Compose service labels for `accounts-db`, `ledger-db`, `userservice`, `contacts`, `balancereader`, `transactionhistory`, `ledgerwriter`, and `frontend`.
- Verified readiness for `userservice`, `contacts`, `balancereader`, `transactionhistory`, `ledgerwriter`, and frontend loopback endpoint.
- Verified database initialization with four seeded demo users and seeded ledger transactions.
- Logged in through frontend as `testuser` with local demo password `bankofanthos`.
- Submitted a `$12.34` deposit through the frontend using the seeded external account and verified the ledger row was persisted.
- Restarted with named volumes preserved and verified the validation transaction remained present.
- Stopped `ledger-db` for the controlled negative check and confirmed validation failed as expected.
- Completed normal cleanup with `docker compose down --remove-orphans`.

## Limitations

- `ENABLE_TRACING=false` is a local runtime difference from Kubernetes to avoid Google Cloud tracing assumptions in Compose.
- `ENABLE_METRICS=false` is a local runtime difference for Java services; the pinned images otherwise initialize Stackdriver metrics and fail outside GCP runtime metadata. Java services use Kubernetes-like local hostnames so the pinned metrics registry startup code can parse `HOSTNAME` without changing application source. Java processor metrics and JVM container support are disabled because this local host exposes cgroup data differently than the pinned JDK expects.
- Load generation is optional and disabled by default.
- Compose validates local functional equivalence only; it does not emulate GKE ServiceAccounts, LoadBalancers, Istio, scheduling, or exact Kubernetes probe timing.

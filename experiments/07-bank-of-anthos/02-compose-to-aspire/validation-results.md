# Bank of Anthos Aspire Validation Results

Date: 2026-07-28
Environment: Ubuntu 24.04 DevBox, .NET SDK 10.0.110, Docker 29.6.1, PowerShell 7.5.7, Aspire AppHost SDK 13.4.6.

## Build

Command:

```bash
dotnet build experiments/07-bank-of-anthos/02-compose-to-aspire/BankOfAnthos.Aspire.sln
```

Result: PASS. The AppHost built with 0 warnings and 0 errors.

## Native Aspire Validation

Command:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/07-bank-of-anthos/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/07-bank-of-anthos/02-compose-to-aspire/src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -StartAppHost -StableSeconds 5
```

Result: PASS.

Observed evidence:

- Validator generated local JWT keys under `.local/jwt/` and confirmed generated state was untracked.
- AppHost build passed before runtime startup.
- Frontend readiness passed at `http://127.0.0.1:8080/ready`.
- Aspire container selection used DCP labels and one shared creator identity: `741701|0001-01-12T21:23:56.580Z`.
- Backend readiness passed from inside the Aspire frontend container for `userservice`, `contacts`, `balancereader`, `transactionhistory`, and `ledgerwriter`.
- Seeded data was present: `users=4`, `transactions=62`.
- Deterministic current-run deposit evidence was observed in `ledger-db`: matching transaction count `0 -> 1`.
- Host exposure check passed: `frontend` was the only host-published service.
- Container stability window passed.
- Resolved image inventory matched the pinned Bank of Anthos image digests and Aspire/DCP labels, for example `frontend-qkjkvcyu`, `ledger-db-fvcdckjy`, and `accounts-db-wnxzqxjx`.

## Concurrent Compose/Aspire Isolation

A temporary Compose file was written outside the repository at `/tmp/bank-of-anthos-compose-concurrent.yaml` with only the frontend host port remapped to `127.0.0.1:18080`. The Compose baseline was started with the 07A directory as project directory so the existing local key mounts resolved exactly like the validated baseline:

```bash
docker compose --project-directory experiments/07-bank-of-anthos/01-kubernetes-to-compose -p bank-of-anthos-compose-concurrent -f /tmp/bank-of-anthos-compose-concurrent.yaml up -d
```

Then the Aspire validator was run while the same pinned-image Compose containers were still running:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/07-bank-of-anthos/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/07-bank-of-anthos/02-compose-to-aspire/src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -StartAppHost -StableSeconds 1
```

Result: PASS.

Isolation evidence:

- Validator selected only resources with Aspire/DCP labels and shared creator identity `764304|0001-01-12T21:29:33.810Z`.
- The inventory printed Aspire resource labels such as `accounts-db-jrmrrzjb`, `ledger-db-qadpzhyn`, `frontend-wexxdbnx`, and `ledgerwriter-hpktwwaq`.
- The deterministic Aspire deposit evidence advanced from `1 -> 2` in the Aspire ledger volume while Compose containers were concurrently running.
- This proves same-image Compose containers did not satisfy Aspire validation.

## Negative Validation

Compose-only negative command, with the Compose frontend ready on `http://127.0.0.1:18080` and no Aspire containers running:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/07-bank-of-anthos/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/07-bank-of-anthos/02-compose-to-aspire/src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -BaseUrl http://127.0.0.1:18080 -StableSeconds 1
```

Result: EXPECTED FAIL. The validator reached Aspire identity validation and failed with:

```text
missing running Aspire-managed container for frontend
```

Missing dependency negative command, after starting Aspire and deliberately stopping the Aspire `ledger-db` container:

```bash
PATH="/home/devclaw-svc/.local/bin:$PATH" /home/devclaw-svc/.local/bin/pwsh -NoLogo -NoProfile -File experiments/07-bank-of-anthos/02-compose-to-aspire/scripts/validate-aspire.ps1 -AppHostProject experiments/07-bank-of-anthos/02-compose-to-aspire/src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj -IdentityOnly -StableSeconds 1
```

Result: EXPECTED FAIL. The validator reached Aspire identity validation and failed with:

```text
missing running Aspire-managed container for ledger-db
```

## Cleanup And Reset

Runtime cleanup checks after validation:

```bash
docker ps -a --filter label=com.microsoft.developer.usvc-dev.group-version=usvc-dev.developer.microsoft.com/v1 --format '{{.Names}} {{.Status}}'
docker compose --project-directory experiments/07-bank-of-anthos/01-kubernetes-to-compose -p bank-of-anthos-compose-concurrent -f /tmp/bank-of-anthos-compose-concurrent.yaml ps -a
```

Result: PASS. No Aspire/DCP containers remained, and the temporary Compose project had no remaining services.

The Aspire database volumes remained as expected until explicit reset:

```text
bank-of-anthos-aspire-accounts-db-data
bank-of-anthos-aspire-ledger-db-data
```

Full reset command:

```bash
docker volume rm bank-of-anthos-aspire-accounts-db-data bank-of-anthos-aspire-ledger-db-data
rm -rf experiments/07-bank-of-anthos/02-compose-to-aspire/.local
```

Generated JWT keys and validator cookies were ignored by `.gitignore`; `git status --short` showed only the new `02-compose-to-aspire/` source directory.

## Notes

- Compose baseline files under `experiments/07-bank-of-anthos/01-kubernetes-to-compose/` were used as read-only input.
- The AppHost preserves the Compose Java service `HOSTNAME` values as environment variables because the pinned Java images parse Kubernetes-style hostnames during local startup even with metrics disabled.
- Independent tester validation is still required before human merge approval; this is developer-produced evidence only.

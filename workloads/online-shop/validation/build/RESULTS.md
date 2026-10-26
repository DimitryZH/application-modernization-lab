# Issue #25 clean-source build evidence

Acceptance passed on 2026-10-26 for contract v1, all eleven explicitly selected
components, `linux/amd64`. Source and executable tooling tested:
`4fd3795de94bd005b7b02b32c6b74abc8775b62c`, based on accepted main
`94c92587a2ae2829aa5d940cb7f54988f587709e`.
The subsequent evidence commit changes documentation/results only; application,
contract and executable tooling inputs are unchanged. No Aspire migration occurs.

## Executed verification

An isolated shared Git clone checked out the full tested SHA detached, with
`core.autocrlf=false`. It received no application files from the working tree.
The runner verified every tracked workload byte against that commit's Git blobs
and rejected undeclared local files in every Docker context. Existing workload
attributes specify `text=auto eol=lf` with binary PNG/JPG/ICO/JAR exceptions.

From that checkout's repository root:

```text
python workloads/online-shop/validation/build/test_build_plan.py
python workloads/online-shop/validation/build/verify.py
```

All **12 behavior tests passed** on the clean committed source. They cover real
contract completeness/COPY inventory, one/all selections, deterministic ordering,
invalid revisions/components/platforms/arguments/paths, missing inputs, mapping
drift and isolation from dirty files and a different HEAD. Additional actual CLI
invocations passed: frontend only; all eleven; reversed selection yielding
byte-identical stdout; invalid component exiting 1 with empty stdout and stderr
diagnostics. The CLI output SHA-256 is in the machine-readable summary.

The runner exercised the generated plan, including full-SHA SOURCE_REVISION and
empty release Go flags, not a second hand-maintained build mapping. All eleven
`docker build` commands executed successfully; Java's Docker build also executed
its Gradle tests. Docker Engine 28.5.1 / BuildKit 0.25.1 used the existing Linux
engine. BuildKit layer and dependency/compiler caches were allowed and used;
neither `--no-cache` nor `--pull` was requested. Cached steps are recorded per
build. Necessary base/package downloads occurred. This is not a fully locked,
uncached or byte-identical reproducibility claim.

All rows below passed platform and exact OCI source-revision-label inspection.
These are **local Docker image IDs**, not registry manifest digests. Unique tags
were `aml-25-da29e55c-<component>:local`.

| Component | Result | Local image ID (`sha256:`) |
|---|---|---|
| adservice | PASS | `19d720d7206bae2cd02787f59a13b2a43be7391dbdbeda9f6dac55f41ae55a19` |
| cartservice | PASS | `e53499ee4f53447b042a4b068f9a9437c8b4b37e292d99320d5139f5a1ce5021` |
| checkoutservice | PASS | `e0ec164d64b6d7ed651aa404647abb6b1af6e746e6abb3025e89bb47a67e7a92` |
| currencyservice | PASS | `d5a1b11c32acc7d4003f798be38255de8eb8f8662eb8b27645fe24ffdbe55595` |
| emailservice | PASS | `afebf4f6adf27c8a7816f691064d5290b3242a7220146ea2c10f5c9688468478` |
| frontend | PASS | `c953b7b5e69e865bc4ea973d995e06a91474cf25f7abd044c0fd3e0d1301fc94` |
| loadgenerator | PASS | `2790afb5e5f251472565a61dcb8141094429b66f63386b4654c4afed51ea211a` |
| paymentservice | PASS | `98f9774ab315a1cff15281547e8b2a142d342d375f50fac26f2756ae7665ada0` |
| productcatalogservice | PASS | `4be0585b3cbaded8607d25436259b73c5f8f091fb926f9b525f2275e46e3aeb0` |
| recommendationservice | PASS | `33825b923f5a8327adebcdcf58c51133d3641662bc4d2a640fb1a0925c614bbd` |
| shippingservice | PASS | `f9a7cbbc326117516e324be90376995a75b790a2116fba98270e1037d95b29fd` |

[Sanitized evidence](evidence-summary.json) records exact commands, revisions,
platforms, labels, local tags/IDs, tests, plan identity, fingerprint method and
cleanup. Raw build logs/plan/result remain ignored under
`validation/build/output/acceptance-da29e55c/`; they are not public attestations.

## Historical fingerprints

Read algorithms: `validation/otel/run.py` hashes sorted repository-relative
UTF-8 paths followed immediately by checkout bytes, without separators. It lists
tracked and nonignored untracked `src/` and `protos/` files. Its label prefix is
`git describe --always --dirty --abbrev=40`, followed by the first 12 hash digits.
`run_redis.py` instead hashes cart-source plus shared-protocol paths with a NUL
separator, so its focused cart hash is not comparable to the all-source hash.

The historical application commit
`469621fd011626f6ce1e7269034aee525d4fb183`, accepted main and tested implementation
have the **same 209 source/protocol paths and identical committed blob bytes**.
Using the all-source algorithm over those Git blobs (also the clean LF checkout)
gives `5976c0eaf5bdcf039292564dbdc4da890b0572be46ae23fecc2265902c788a47`.

Before creating the isolated checkout, the existing clean Git working tree
reproduced the full later recorded hash exactly:
`365c21c43d8a0b68ca8945e4d3c84e40d36bf81f7ea3bd8976b7b3439d2c0615`.
Exactly 67 of those 209 files differed from Git blobs, entirely by CRLF versus LF;
normalizing those differences reproduced the committed bytes. Their exact paths
are recorded in the summary. The other 142 files matched byte-for-byte. No
application inputs were changed to obtain this result. A hypothetical uniform
CRLF text checkout gives `1e7f9abf75ddbabd399986f45f51252b007855286d8e3d333022d4281643b49a`,
which is not the observed mixed checkout. Git status alone does not establish
checkout-byte identity because it normalizes line endings.

Thus the suffix in historical label
`469621fd011626f6ce1e7269034aee525d4fb183-dirty.365c21c43d8a` agrees with the
later full hash and can be reconstructed from committed contents with the observed
line endings. The dirty marker applies to tracked repository state globally; it
does not identify which paths changed or prove application-source changes. This
comparison does not authenticate the historical build, prove its exact original
file inventory, establish publisher provenance or make its old images identical
to these newly executed builds. Today's SOURCE_REVISION labels are full commit
SHAs, separate from input fingerprints and local image IDs.

## Scope, warnings and cleanup

No application, dependency, Dockerfile or runtime-configuration correction was
needed. Documentation clarifies frontend's assistant endpoint format. Inherited
npm advisories, Gradle deprecations, optional-backend .NET trim warnings and the
load-generator shell-entrypoint warning remain visible in ignored logs. No
dependency/security audit or upgrade is claimed.
Currency's npm install reported 35 advisories, including 8 high and 2 critical;
successful source builds do not grant production release eligibility.

No new full runtime suite was required or run: application/runtime inputs are
unchanged. Historical [OTel](../otel/RESULTS.md) and
[Redis](../otel/REDIS-RESULTS.md) acceptance remain explicitly separate evidence.
Cloud backends, publication, downstream adoption and deployment are unexecuted.
Redis remains external with unresolved publisher lineage and fresh-mirror,
release-review and downstream-adoption requirements from [REDIS.md](../../REDIS.md).

The isolated acceptance checkout and test fixtures were removed after capture.
The build-only runner created no application runtime containers, networks or
volumes. All eleven local image tags and BuildKit caches are intentionally retained;
raw logs remain ignored. Historical images/evidence and frozen experiments are
unchanged. Git whitespace validation passed.

AML's issue #25 acceptance is met. CI Build Platform can implement source
consumption/publication using the contract and planner without another AML
inventory task; release eligibility and deployment remain with their owners.

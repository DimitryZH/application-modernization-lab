# Source-to-build handoff, contract v1

Inline file paths are workload-relative unless stated otherwise. Commands retain their original working directory; commands beginning with `workloads/online-shop/` run from the repository root. Markdown links are document-relative.

`build.contract.json` describes future source builds. `images.lock.json` remains
the historical published-image authority; its namespace artifacts are not builds
of this contract. The planner cross-checks component IDs, roles and paths against
that record. Redis is external, not a twelfth source build.

## Consumer interface

Inputs are repository `https://github.com/DimitryZH/application-modernization-lab`,
an existing full lowercase 40-character commit SHA, workload `workloads/online-shop`,
explicit component IDs, platform `linux/amd64`, and optional component-qualified
build arguments. All contract/plan paths are workload-relative; Docker COPY paths
are context-relative. No target means the final Dockerfile stage. Preparation is
explicitly empty for all eleven components. No build secrets or host environment
variables are required. Docker network access to declared downloads is required.

Use Python 3.10+ and Git. Obtain the helper from the selected revision too: CI
should fetch and check out the requested SHA before invoking its helper. The
helper reads contract, mapping, Dockerfiles, ignore rules and files from Git
objects at `--revision`; it does not read their working-tree equivalents. It
validates the whole contract even for a one-component selection. Diagnostics go
to stderr, JSON alone to stdout, failure exits nonzero. It never builds or publishes.

```powershell
$revision = git rev-parse HEAD # full immutable SHA after checkout
python workloads/online-shop/build_plan.py --revision $revision --components frontend
python workloads/online-shop/build_plan.py --revision $revision --components adservice cartservice checkoutservice currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice shippingservice
python workloads/online-shop/build_plan.py --revision $revision --components frontend --build-arg 'frontend.SKAFFOLD_GO_GCFLAGS=all=-N -l'
```

Selections and arguments are sorted in output. Plans contain no workstation
paths, timestamps or random identifiers. `SOURCE_REVISION` is always the selected
full SHA, used by every Dockerfile for the OCI revision label and version default.
The only other argument is Go's `SKAFFOLD_GO_GCFLAGS`: Docker default unset,
intended empty release value; accepted debug value `all=-N -l`. Arbitrary compiler
flags are outside v1. Unknown/duplicate arguments and components fail closed.

Each plan records actual COPY source expressions, ignore rules, consumed tracked
files and SHA-256 values, plus the Dockerfile SHA-256. Intermediate-stage COPY
inputs are outputs of the declared build, not host inputs. Dockerfile and ignore
files remain build-control inputs even when Docker excludes them from COPY.
The implementation supports current COPY/ignore syntax, rejects ADD, complex new
ignore rules and unsupported COPY flags, and requires a deliberate update when
those semantics change. COPY/ADD/FROM/ARG recognition accepts mixed instruction
case and leading whitespace. COPY `--from` must identify an earlier internal
stage by name or zero-based index; external images, named contexts, current/future
stages and additional flags are rejected. Multiline input instructions, heredocs,
ONBUILD and nondefault escape directives require explicit planner support.
Symlinks, submodules and LFS pointers within consumed
inputs are rejected. The current workload contains none; there are no hidden
parent-context inputs. Build-time platform-generated Docker ARGs are Docker's
own interface, not undeclared application configuration.

CI Build Platform owns execution/publication. It should materialize an isolated
checkout of the selected SHA with `core.autocrlf=false`, reject local/untracked
context artifacts, verify checkout bytes against plan hashes, then for each plan
entry run this argument-vector pattern from the repository root:

```text
docker build --platform <plan.platform> -t <new-build-tag> -f <workloadPath>/<dockerfile> --build-arg SOURCE_REVISION=<sourceRevision> [other plan buildArguments] <workloadPath>/<buildContext>
```

Do not add a target when it is null. No generation step is needed. Record the
local image ID separately from any later registry manifest digest. Local acceptance
uses `python workloads/online-shop/validation/build/verify.py`; it exercises this
plan and verifies every tracked workload byte before building all eleven images.
That local evidence runner is not a CI publishing framework. Container Platform
owns release composition/eligibility; SRE Platform owns deployment and telemetry
infrastructure. No downstream implementation is part of AML acceptance.

## Direct and generated inputs

The contract lists dependency files, tracked generated inputs, assets, external
downloads, base images and locking limits per component. The plan is the exact
COPY-expanded file inventory. In particular frontend includes templates/static
assets, catalog includes `products.json`, currency includes conversion data, email
includes its HTML template, Java includes its Gradle wrapper JAR/properties/scripts,
and cart builds only `src/cartservice/src`, not its parent solution/tests.

Go module files/checksums and npm lockfiles are consumed directly. Python
`requirements.txt` is consumed; `.in` describes regeneration (it can also be copied
by COPY `.` but is not passed to pip). Cart NuGet and Java Gradle dependencies lack
complete transitive locking. Python requirements lack artifact hashes. Apt/apk
repositories, unpinned base tags, wrapper distribution and package repositories
remain external mutable dependencies. Cache reuse is allowed and disclosed.
This contract does not promise fully locked or byte-identical reproducibility.

Shared `protos/demo.proto` and `protos/grpc/health/v1/health.proto` are
**regeneration-only** inputs; Docker contexts do not reach their parent directory.
From each service directory, established `bash genproto.sh` performs:

| Components | Local input/output | Generation tools |
|---|---|---|
| frontend, checkoutservice, productcatalogservice, shippingservice | shared demo to tracked `genproto/demo*.pb.go` | protoc; headers record 3.6.1, protoc-gen-go 1.34.2, protoc-gen-go-grpc 1.5.1; install plugins with `go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2` and `go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1`; protoc itself is operator-provided |
| currencyservice, paymentservice | copy shared protocol tree to tracked `proto/`; loaded dynamically | bash, mkdir, cp; no compiler |
| emailservice, recommendationservice | shared demo to tracked `demo_pb2.py`, `demo_pb2_grpc.py` | `python -m grpc_tools.protoc`; scripts say install requirements, but current runtime locks do not include grpcio-tools; operator must supply a compatible generator and review generated diffs; exact historical generator version is not established |
| adservice | shared demo copied to tracked `src/main/proto/demo.proto` | bash/cp; Gradle generates Java bindings during Docker build with protoc 4.33.1/grpc-java 1.76.0, wrapper Gradle 8.14.3 |
| cartservice | tracked independent `src/protos/Cart.proto` | NuGet Grpc.Tools transitively supplies generation during restore/publish; no shared-copy script |
| loadgenerator | no protobuf inputs | none |

No ordinary image build requires these host regeneration tools. After a shared
protocol edit, operators run affected scripts, review/commit local copies and
bindings, review cart's separate Cart subset for compatibility, then explicitly
select the affected clients/servers. A general demo protocol change can require
all ten services; loadgenerator needs rebuilding only if its own code/dependencies
change. A shared health change requires reviewing Node copies; other services use
library health definitions. There is no automatic changed-file selection.
No other workload-root assets enter the eleven Docker contexts.

## Verification

```text
python workloads/online-shop/validation/build/test_build_plan.py
python workloads/online-shop/validation/build/verify.py
```

The second command requires an isolated clean checkout with LF bytes, Git history
containing the historical revision, and Docker Linux/amd64. It uses unique local
tags, preserves raw logs in ignored output, and never publishes. It may reuse
BuildKit layers and compiler/dependency caches. See [build evidence](../validation/build/RESULTS.md)
for the actual tested commit, results, fingerprint comparison and cleanup.
See [runtime handoff](RUNTIME.md), [telemetry](TELEMETRY.md) and [Redis](REDIS.md)
for independent runtime contracts.

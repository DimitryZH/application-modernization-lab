# Trail Supply foundation — static results

Date: 2026-11-27. Scope: independent workload foundation only.
Base: AML `67b6cd85ae01c698bbf86904d953d5145b7b5820`,
`workloads/online-shop`. These are new static checks, not inherited runtime results.

| Executed check | Result |
|---|---|
| `python -B workloads/trail-supply/validation/build/test_build_plan.py` | PASS: 23 tests, including all eleven build plans, selected-revision isolation and negative contract/path/platform/ARG/COPY checks |
| `python -B workloads/trail-supply/validation/otel/test_redis_contract.py` | PASS: 6 tests; effective Compose render, runtime/storage/source drift rejection |
| `python -B workloads/trail-supply/local/test_compose.py` | PASS: 5 tests; local source contexts, direct endpoints, loopback-only exposure, Redis security/init ownership, distinct project storage |
| Application/protocol/license/runtime fixture copy | PASS: 215 preserved files have the accepted Git blob bytes and modes; all ten executable modes preserved |
| Python AST / JSON parsing | PASS for the new workload, excluding ignored generated output |
| Markdown local file targets | PASS; repository overview and Trail Supply documentation |
| Git whitespace and scope checks | PASS; only root README and the new workload differ from the base |

Planner tests construct a disposable committed repository containing only
`workloads/trail-supply`, with no Online Shop directory. This verifies independence
without changing the original workload or weakening the inherited planner guards.
The direct planner CLI must use the final committed revision, not the pre-fork
base (which contains no Trail Supply workload).

Copy checks compare accepted Git objects with both new working bytes and staged
blob/mode entries. The preserved set includes all `src/`, `protos/`, LICENSE,
`.gitattributes`, the inherited Kubernetes manifest and both Redis contracts.
Ten historical evidence/review/result files were excluded and are enumerated in
[source-lineage.json](../source-lineage.json). Original evidence remains linked
at immutable source URLs in [UPSTREAM.md](../docs/UPSTREAM.md).

Docker Compose was used only for client-side configuration rendering. Docker
Desktop was not started; no container/image build, pull, startup, runtime test,
browser review, registry publication, attestation, deployment or cloud change was
performed. Recommendation deadline source/tests remain byte-identical, and its
container unit runner now includes the dedicated regression suite; that suite
was not executed in this foundation stage.

The pinned Redis mirror still has inherited pending publication, equality and SDP
attestation requirements. Static rendering does not prove image pullability.
Future strict build acceptance requires a clean LF checkout without local context
artifacts. Browser/CDN/font behavior and checkout must be checked after explicit
runtime startup using [local review commands](../local/README.md).

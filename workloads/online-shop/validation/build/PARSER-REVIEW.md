# PR #26 parser review corrections

The corrective commit's exact SHA and post-commit checks are recorded in
[PR #26](https://github.com/DimitryZH/application-modernization-lab/pull/26).
Historical build evidence in RESULTS.md and evidence-summary.json is unchanged:
those eleven builds tested source/tooling
`4fd3795de94bd005b7b02b32c6b74abc8775b62c`, not the parser correction.

## Corrections

Input instruction recognition now handles leading whitespace and mixed-case
COPY, ADD, FROM and ARG. ADD remains unsupported. Unsupported input syntax fails
explicitly. Continued shell command bodies are not mistaken for instructions.

COPY `--from` resolves only earlier declared stage names or valid zero-based
stage indices. Unknown names, external images/named contexts, self/forward
references and unsupported flags/syntax fail, including flags following a valid
internal-stage reference. Intermediate-stage output files are not host inputs;
the planner does not attempt to predict their contents.

## Regression verification

```text
python workloads/online-shop/validation/build/test_build_plan.py
```

All 21 tests passed, including nine new behavioral tests with committed
disposable Git snapshots. Coverage includes case/indentation variants, real
additional input hashes, missing sources, ADD rejection, FROM/ARG recognition
and drift, named/numeric internal stages, unknown/external/self/forward stages,
unsupported syntax/flags and shell continuation handling.

All eleven component plans were generated. The old and corrected planners
produced identical complete plans for the pre-correction revision
`c9279d7e5de519e17d8e6910e831b16f0e32b841`. The canonical component-plan JSON
SHA-256 was `969392626a7bb7a44da0f9c26e37a887b134c13e1cfef6fc0e54e9393f13d05e`
(UTF-8 `json.dumps(components, sort_keys=True, separators=(',', ':'))`).
The corrective revision's plans are compared after excluding only source/tooling
revision metadata and each SOURCE_REVISION build argument. COPY expressions,
ignore rules, input paths/content hashes, Dockerfile hashes and remaining build
settings must all remain identical.

No application, Dockerfile, contract or runtime configuration changed. A new full
Docker rebuild/runtime run is unnecessary for this parser-only correction and
was not performed. Historical mutable-dependency, security-advisory and Redis
lineage/adoption limitations remain. The parser deliberately supports the v1
subset, not arbitrary Dockerfile syntax; extensions require explicit validation.

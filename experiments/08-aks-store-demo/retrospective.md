# Experiment 08: AKS Store Demo Retrospective

## 1. Executive summary

Experiment 08 produced two independent accepted outcomes.

Evidence-backed fact: Experiment 08A established an accepted Docker Compose baseline for the official AKS Store Demo, pinned to upstream commit `7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5` and merged through PR #15 at merge commit `38ab6b49868c8b4e490e2464d749f8b0fa92e905`.

Evidence-backed fact: Experiment 08B successfully migrated that accepted baseline to a reproducible .NET Aspire AppHost model, with final PR head `bdad00156bd9d6035dc400d56b9a5d39fd39d0e7` merged through PR #17 at merge commit `fe23e445c39ce0b7636641a14bacef671482fad5`.

Decision input: The OpenClaw/DevClaw worker-orchestration workflow evaluated during the same historical experiment informed the AI Operations Platform decision not to select the evaluated OpenClaw/DevClaw architecture as the primary orchestration foundation. This does not invalidate the accepted Aspire migration and is not a universal rejection of OpenClaw or DevClaw.

Engineering inference: OpenClaw may remain an optional communication gateway or interactive runtime candidate, subject to separate operational validation outside Experiment 08.

Insufficient evidence: Experiment 08 did not produce controlled worker/direct runtime parity evidence, exact token-cost totals, exact operator-hour totals, exact wall-clock comparisons, managed-service restart persistence PASS evidence, or VM reboot persistence PASS evidence.

## 2. Experiment objective

The application-modernization objective was to preserve the accepted AKS Store Demo runtime behavior while translating the local orchestration model from Docker Compose to .NET Aspire.

The orchestration objective was separate: evaluate whether a role-based OpenClaw/DevClaw worker workflow could support architecture research, implementation, testing, correction, review, and closeout with durable GitHub evidence and human approval boundaries.

## 3. Original orchestration hypothesis

The working hypothesis was that OpenClaw could provide the operator-facing gateway and DevClaw could coordinate role-based architect, developer, and tester sessions through GitHub-native task state.

Engineering inference: The hypothesis was reasonable for research because prior experiments had shown useful role separation, approval gates, and structured reports. The hypothesis still required execution-readiness proof for filesystem, Git, Docker/runtime, validation, push, PR update, and recovery capability before it could be treated as a primary platform-control-plane pattern.

## 4. Experiment 08A Compose baseline

Experiment 08A created the immutable source baseline under `experiments/08-aks-store-demo/01-compose-baseline/`.

The accepted baseline preserved nine required non-AI services: `documentdb`, `rabbitmq`, `order-service`, `makeline-service`, `product-service`, `store-front`, `store-admin`, `virtual-customer`, and `virtual-worker`.

The baseline validation recorded:

- source provenance through `upstream-source.sha256`;
- loopback-only host exposure for storefront and admin endpoints;
- internal-only backend service exposure;
- product workflow evidence;
- unique current-run order submission;
- RabbitMQ `orders` queue behavior;
- makeline consumption;
- DocumentDB-backed current-run order visibility;
- negative validation for RabbitMQ failure and recovery;
- secret hygiene with local runtime artifacts under ignored `.local/`.

Persistence boundary: Experiment 08A classified `makeline-service` restart as PASS while DocumentDB remained unchanged. It did not claim durable DocumentDB persistence across deletion, recreation, or full reset.

## 5. Experiment 08B Aspire migration

Experiment 08B created the Aspire migration under `experiments/08-aks-store-demo/02-compose-to-aspire/`.

Evidence-backed fact: The final accepted AppHost uses .NET SDK `10.0.110` and Aspire AppHost SDK `13.4.6`, keeps application source immutable, represents the nine required non-AI services, keeps optional `ai-service` outside default PASS criteria, and preserves loopback-only user-facing endpoints with internal-only backend services.

The migration used Dockerfile-based Aspire container resources for application services and pinned image resources for `documentdb` and `rabbitmq`. It did not redesign service internals, add cloud resources, or add named volumes.

## 6. Validation performed

Experiment 08A accepted validation:

- `./scripts/validate-compose.sh`: PASS;
- `./scripts/validate-negative.sh`: PASS;
- cleanup and source-integrity checks passed;
- no durable DocumentDB recreation claim was made.

Experiment 08B accepted validation on the final PR head included:

- AppHost build and version validation;
- clean positive functional validation;
- nine-resource Aspire/DCP identity checks;
- loopback and internal endpoint checks;
- product workflow;
- fresh unique order workflow;
- RabbitMQ queue and publication evidence;
- makeline consumption;
- DocumentDB-backed visibility;
- `makeline-service` restart persistence while DocumentDB remained unchanged;
- RabbitMQ negative validation;
- functional recovery with a fresh order;
- cleanup isolation;
- ownership guardrails;
- intentional validation failure recovery and cleanup;
- second fresh positive validation;
- Experiment 08A integrity;
- Git hygiene, executable mode verification, secret scan, and final port/container cleanup.

Insufficient evidence: The accepted validation did not prove durability across DocumentDB recreation, full reset, managed-service restart persistence for OpenClaw, VM reboot persistence, or worker/direct environment parity.

## 7. Migration result

Evidence-backed fact: Experiment 08B successfully migrated the accepted AKS Store Demo Compose baseline to a reproducible .NET Aspire AppHost model.

The migration result remains technically valid because the accepted final closeout explicitly retained the Aspire migration as a completed Application Modernization Lab result while separately recording the orchestration-platform concern.

## 8. Orchestration workflow evaluated

The evaluated workflow used GitHub issues, PRs, comments, branch heads, merge commits, architecture gates, implementation gates, tester/correction reports, and human closeout comments as durable coordination evidence.

OpenClaw/DevClaw workflow concepts evaluated during the experiment included:

- role separation;
- architecture and implementation gates;
- issue-driven coordination;
- human approval boundaries;
- structured developer and tester reports.

Evidence boundary: Agent-authored reports are useful reported evidence unless corroborated by committed files, PR state, merge commits, human approval, or human closeout.

## 9. What worked

The application-modernization track worked:

- the Compose baseline was accepted and merged;
- the Aspire migration was accepted and merged;
- validation was encoded in repository scripts and documented results;
- GitHub issue/PR/commit state preserved a durable audit trail;
- human approval gates controlled architecture, implementation, final validation, merge, and closeout;
- cleanup, isolation, negative validation, and ownership guardrails improved confidence in the local Aspire runtime.

The orchestration research track also produced reusable governance patterns: role separation, architecture-first planning, explicit approvals, immutable baselines, structured closeout, and evidence classification.

## 10. What did not work reliably

Decision input: The evaluated OpenClaw/DevClaw worker-orchestration path encountered repeated worker-runtime, sandbox, filesystem, Docker-access, recovery, and workflow-control concerns. These concerns made continued worker orchestration disproportionate for the remaining Experiment 08B work.

Engineering inference: For a primary platform orchestrator, dispatch acceptance, gateway readiness, plugin loading, and worker-session creation are not enough. Capability negotiation must happen before an execution attempt becomes active.

Attribution boundary: The accepted evidence does not attribute every failure to OpenClaw or DevClaw product defects. Some attribution remains unresolved across product behavior, integration behavior, compatibility overlay, sandbox, host configuration, permissions, and environment.

## 11. Why direct Codex completion was authorized

Evidence-backed fact: Human approval on issue #16 authorized final Experiment 08B validation and correction directly by Codex and explicitly prohibited OpenClaw/DevClaw workers, subagents, developer sessions, tester sessions, worker dispatch, and worker capability probes for that final stage.

Evidence-backed fact: Final direct completion reports recorded PASS on final PR head `bdad00156bd9d6035dc400d56b9a5d39fd39d0e7`, and the human closeout accepted the final migration result.

Insufficient evidence: Direct Codex completion did not prove identical environment, identical permissions, identical starting conditions, Docker/runtime parity, lower execution time, lower token cost, or lower operator effort compared with worker execution.

## 12. Separation of migration and orchestration outcomes

Evidence-backed fact: The Aspire migration succeeded and remains technically valid.

Decision input: The evaluated OpenClaw/DevClaw architecture was not selected as the primary orchestration foundation for the AI Operations Platform.

These conclusions must stay separate. The orchestration non-selection does not convert Experiment 08B into a failed migration, and the successful Aspire migration does not prove OpenClaw/DevClaw was suitable as the primary platform orchestrator.

## 13. Engineering lessons

Application modernization lessons:

- start from an immutable accepted baseline;
- preserve service identity and runtime contracts before changing orchestration tooling;
- validate behavior through product, order, queue, consumer, persistence, endpoint, negative, recovery, and cleanup paths;
- keep optional external-AI functionality outside default PASS criteria when the source treats it as optional;
- document persistence limits explicitly.

Orchestration lessons:

- durable GitHub state is stronger evidence than ephemeral worker-session state;
- role separation and human gates remain valuable independently of a specific worker runtime;
- executor capability must be negotiated explicitly before implementation starts;
- cleanup and ownership boundaries need adversarial validation where runtime resources can overlap;
- qualitative operational burden can inform an architecture decision, but exact time, cost, token, or recovery magnitudes require measurement.

## 14. Impact on the AI Operations Platform

Decision input: Experiment 08 contributed to the AI Operations Platform conclusion that the evaluated OpenClaw/DevClaw architecture should not be selected as the primary orchestration foundation.

Evidence-backed fact from ADR 0001: The accepted platform decision preserves GitHub-native auditability, explicit human approval gates, logical roles, durable external state, replaceable executors, and pre-execution capability negotiation while not selecting a replacement framework.

This retrospective is an Application Modernization Lab document. It references the AI Operations Platform decision only to explain how the Experiment 08 orchestration evidence was used; it does not reopen the platform decision or choose a replacement orchestrator.

## 15. Retained patterns

The following patterns remain useful:

- immutable accepted source baselines;
- architecture-first planning;
- logical architect/developer/tester responsibilities;
- GitHub issues and pull requests as durable workflow evidence;
- explicit human approval gates;
- negative validation and recovery validation where directly evidenced;
- cleanup ownership guardrails;
- governed reusable migration knowledge with target-specific validation;
- optional executor model, subject to capability negotiation and benchmark validation.

## 16. Rejected assumptions

The accepted evidence rejects these assumptions for future primary orchestration work:

- gateway health proves execution readiness;
- plugin loading proves engineering-task capability;
- dispatch acceptance proves worker command execution;
- worker-session creation proves filesystem, Git, Docker/runtime, validation, push, PR update, or completion capability;
- narrow sandbox recovery proves a complete developer workflow;
- direct Codex completion proves worker/direct environment parity;
- OpenClaw/DevClaw non-selection invalidates successful application-modernization results;
- successful application modernization proves the evaluated worker orchestration architecture should be selected.

## 17. Known limitations

Experiment 08 limitations:

- `DocumentDB` remains container-local;
- no durability across DocumentDB recreation, resource deletion, or full reset is claimed;
- optional `ai-service` remains outside default PASS criteria;
- the ownership guardrail suite did not emulate a complete pre-existing unrelated nine-resource DCP topology before AppHost startup, and that edge case was accepted as non-blocking;
- Experiment 08 did not execute the later AI Operations Platform acceptance benchmark;
- no exact historical time, token, dollar-cost, operator-hour, or recovery-hour measurements were recorded;
- no managed OpenClaw service restart persistence PASS or VM reboot persistence PASS claim is made here.

## 18. Public evidence references

Application Modernization Lab references:

- Experiment 08A issue: https://github.com/DimitryZH/application-modernization-lab/issues/14
- Experiment 08A PR: https://github.com/DimitryZH/application-modernization-lab/pull/15
- Experiment 08A merge commit: `38ab6b49868c8b4e490e2464d749f8b0fa92e905`
- Experiment 08B issue: https://github.com/DimitryZH/application-modernization-lab/issues/16
- Experiment 08B PR: https://github.com/DimitryZH/application-modernization-lab/pull/17
- Experiment 08B final head: `bdad00156bd9d6035dc400d56b9a5d39fd39d0e7`
- Experiment 08B merge commit: `fe23e445c39ce0b7636641a14bacef671482fad5`
- Experiment 08B final closeout: https://github.com/DimitryZH/application-modernization-lab/issues/16#issuecomment-5158539452
- Compose baseline: `experiments/08-aks-store-demo/01-compose-baseline/`
- Aspire migration: `experiments/08-aks-store-demo/02-compose-to-aspire/`

AI Operations Platform references:

- Umbrella issue #8: https://github.com/DimitryZH/ai-operations-platform/issues/8
- Evidence issue #9: https://github.com/DimitryZH/ai-operations-platform/issues/9
- Evaluation issue #10: https://github.com/DimitryZH/ai-operations-platform/issues/10
- ADR issue #13: https://github.com/DimitryZH/ai-operations-platform/issues/13
- Accepted evidence index: https://github.com/DimitryZH/ai-operations-platform/blob/main/docs/research/openclaw-devclaw/evidence-index.md
- Accepted orchestration evaluation: https://github.com/DimitryZH/ai-operations-platform/blob/main/docs/research/openclaw-devclaw/orchestration-evaluation.md
- ADR 0001: https://github.com/DimitryZH/ai-operations-platform/blob/main/docs/adr/0001-primary-orchestrator-foundation.md

## 19. Final conclusion

Experiment 08 is a successful application-modernization experiment and a useful orchestration research input.

The accepted AKS Store Demo Compose baseline was migrated to .NET Aspire and validated in a bounded local runtime model. Separately, the evaluated OpenClaw/DevClaw worker-orchestration architecture was not selected as the AI Operations Platform primary orchestrator. Both conclusions stand together without collapsing one into the other.

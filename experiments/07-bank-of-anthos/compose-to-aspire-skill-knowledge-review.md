# Experiment 07 Compose-to-Aspire Skill Knowledge Review

## 1. Executive Summary

This review evaluates the active `compose-to-aspire-migration` skill after Experiment 07A and 07B.

The review recommends a targeted skill update.

The active skill was effective as a general migration playbook. It already covered baseline freeze, Compose inventory, resource-type selection, container-resource modeling, endpoint exposure, validation beyond health checks, shared Aspire run identity, concurrent Compose/Aspire isolation, negative validation, cleanup, independent review, and approval boundaries.

Three bounded improvements are recommended. They should clarify recurring migration concerns without adding Bank of Anthos names, issue numbers, worker identities, image digests, credentials, or transient runtime evidence:

- preserve container runtime assumptions that may be encoded in environment variables, hostnames, commands, working directories, users, or runtime flags;
- make stateful validation explicitly include a controlled AppHost stop/start with storage preserved, not only initial database evidence or volume existence;
- document relative bind-mount and project-directory semantics when copying or overriding Compose files for comparison or concurrent validation.

No skill redesign is justified.

## 2. Scope and Independence

This review was performed directly in this Codex session. DevClaw and OpenClaw were treated only as evidence sources. No DevClaw worker was dispatched, reused, or inspected through workflow tools. No OpenClaw Gateway call, DevClaw script execution, Skill Workshop action, skill proposal, workflow transition, label mutation, or active skill modification was performed.

Repository documentation and GitHub-facing content remain in English. The supporting `DimitryZH/ai-operations-platform` repository was used as read-only evidence.

## 3. Evidence Inventory

| Evidence | Source | Evidence Type | Notes |
| --- | --- | --- | --- |
| Active skill file and references | `/home/devclaw-svc/.openclaw/workspace/skills/compose-to-aspire-migration/` | Direct filesystem evidence | Read-only SSH filesystem read on Agent DevBox; no DevClaw/OpenClaw command. |
| Skill proposal manifest | `ops/devclaw-workflows/application-modernization-lab/issue-8/2026-07-27/knowledge-review/evidence/proposals-manifest-after-apply.json` in `DimitryZH/ai-operations-platform` | Preserved historical evidence | Shows applied proposal id and metadata for `compose-to-aspire-migration`. |
| Experiment 07A source and validation | `experiments/07-bank-of-anthos/01-kubernetes-to-compose/` | Direct repository evidence | Compose baseline, validator, README, validation results. |
| Experiment 07B source and validation | `experiments/07-bank-of-anthos/02-compose-to-aspire/` | Direct repository evidence | Aspire AppHost, validator, README, validation results. |
| Issue #8 | GitHub issue `#8` | Task requirements | Compose baseline requirements and validation expectations. |
| PR #9 | GitHub PR `#9` | Implementation, review, merge evidence | Merged at `3de8845412853525aeb77d85db23f2d14b1bfc73`; includes tester and corrective validation comments. |
| Issue #10 | GitHub issue `#10` | Task requirements | 07B migration, skill reuse, isolation, persistence, and validation requirements. |
| PR #11 | GitHub PR `#11` | Implementation, skill-use, validation, merge evidence | Merged at `5976290742724acfef15766b53dba39f7a8484e9`; head commit `8649b3be4bc63db80a1e185f42a0dbd5d0c21aa1`. |
| Issue #12 | GitHub issue `#12` | Tracking issue | Open tracking issue with exact requested title. |
| Workflow scripts | `ops/devclaw-workflows/application-modernization-lab/issue-10/2026-07-28/` in `DimitryZH/ai-operations-platform` | Read-only orchestration evidence | Used to separate DevClaw workflow mechanics from migration methodology. |
| Workflow commit | `c2367db0f19f445718083da16dc3075cb4ff2f79` in `DimitryZH/ai-operations-platform` | Commit evidence | Adds issue #10 workflow operation scripts. |

Evidence distinction: implementation files and validation scripts are direct evidence. Worker statements in PR or issue text are treated as claims unless corroborated by committed files, validation results, PR diffs, or merge evidence.

## 4. Active Skill Baseline

Active skill path:

```text
/home/devclaw-svc/.openclaw/workspace/skills/compose-to-aspire-migration/SKILL.md
```

Active baseline checksum:

```text
d4631c7a987092f9247a615d4917cbd55fb453f543ca93273b506c35ffb6469f  SKILL.md
```

Known proposal identifier:

```text
compose-to-aspire-migration-20260721-25daeaebee
```

Proposal manifest evidence records it as an applied `create` proposal with skill name/key `compose-to-aspire-migration`, created `2026-07-21T18:08:53.713Z`, updated `2026-07-21T19:27:18.843Z`, scan state `clean`.

Relevant active files:

| File | SHA-256 |
| --- | --- |
| `SKILL.md` | `d4631c7a987092f9247a615d4917cbd55fb453f543ca93273b506c35ffb6469f` |
| `references/aspire-modeling.md` | `97f0077d386f5ecae055428fae9961a33e3e8f247a3ee346eb6606b1ea02fe03` |
| `references/compose-inventory.md` | `832c0ae2f89403d8e87a48753888c46a44f36b642246a19dc78fd5c35aedd11d` |
| `references/failure-modes.md` | `0eca396d7834146c57c3651f6d433160ed2c15c8870753232f7adf18ad44ed77` |
| `references/validation-checklist.md` | `e0e66de52684c02128414b2eb9544a6e25438324c0c04174326afafd20420fb3` |

Current section structure:

- Purpose
- Eligibility And Stop Conditions
- Baseline Freeze And Repository Boundaries
- Migration Workflow
- Mandatory Validation Requirements
- Prohibited Actions And Approval Boundaries
- Completion Checklist
- Supporting references for Aspire modeling, Compose inventory, failure modes, and validation checklist

The inspected content is active workspace skill content, not only a copy.

## 5. Experiment 07A Context

Experiment 07A created the Bank of Anthos Docker Compose baseline under `experiments/07-bank-of-anthos/01-kubernetes-to-compose/`.

Direct evidence:

- Issue #8 required inventory, secrets handling, loopback frontend exposure, optional load generator behavior, readiness validation, functional validation, persistence, negative dependency checks, and no secret leakage.
- PR #9 added the baseline and was merged at `3de8845412853525aeb77d85db23f2d14b1bfc73`.
- The final PR head was `71d059bf5871d2bc5776a9a26688a3e410f78f62`, after a corrective validation commit.
- The Compose validator verifies exact Compose service labels, backend readiness from inside the Compose network, frontend login, deposit, ledger persistence across restart, negative `ledger-db` behavior, cleanup, and untracked local JWT material.
- Human review required stronger post-deposit UI validation, which was then implemented and confirmed by tester evidence.

Inference: 07A established a stronger source baseline for 07B because it recorded exact service identities, seed data behavior, runtime differences, and failure conditions before Aspire work began.

## 6. Experiment 07B Context

Experiment 07B converted the validated Compose baseline into an image-only .NET Aspire AppHost under `experiments/07-bank-of-anthos/02-compose-to-aspire/`.

Direct evidence:

- Issue #10 required use of the active skill as a general playbook, while prohibiting active skill changes or Skill Workshop proposals.
- PR #11 added the Aspire AppHost and validation assets in commit `8649b3be4bc63db80a1e185f42a0dbd5d0c21aa1`.
- PR #11 was merged at `5976290742724acfef15766b53dba39f7a8484e9`.
- The AppHost models all Bank of Anthos services as container resources, keeps two separate PostgreSQL containers and volumes, preserves service names in environment values, mounts JWT keys read-only, publishes only frontend, and keeps load generator optional.
- `validation-results.md` records AppHost build, native validator pass, DCP creator identity selection, backend readiness from inside frontend, seeded data, deterministic deposit evidence, host exposure check, concurrent Compose/Aspire isolation, Compose-only expected failure, missing `ledger-db` expected failure, cleanup, and reset.

Inference: the migration preserved the validated image behavior and avoided source-level integration work because the application was polyglot and image-pinned.

## 7. Skill Usage by Role

### Architect

Observed evidence:

- The issue #10 workflow script required the architect to use the active skill as reusable guidance and not modify or propose changes to it.
- Issue #10 architecture requirements closely match active skill sections: Compose inventory, resource-type selection, endpoint exposure, stateful resources, readiness, lifecycle, rollback, cleanup, negative validation, and isolation.

Inference:

- The architecture role was steered by skill-covered categories, especially Baseline Freeze, Migration Workflow, Aspire Modeling, Compose Inventory, Validation Checklist, and Failure Modes.
- Application-specific decisions still required discovery: keeping both PostgreSQL databases as validated image containers, preserving Bank of Anthos service DNS values, local JWT material boundaries, Java runtime flags, and the optional load generator default.

### Developer

Observed evidence:

- PR #11 states the skill was loaded in the fresh developer session before repository changes.
- PR #11 lists used sections: Baseline Freeze And Repository Boundaries, Migration Workflow, Mandatory Validation Requirements, Prohibited Actions And Approval Boundaries, plus compose inventory, Aspire modeling, validation checklist, and failure modes references.
- The AppHost and validator directly reflect these sections: frozen 07A input, image-only container resources, loopback-only frontend, separate volumes, read-only JWT mounts, optional load generator, shared DCP identity checks, backend readiness probes, and negative validation.

Developer-discovered gaps or adaptations:

- Java services needed Compose/Kubernetes-style `HOSTNAME` values preserved.
- Frontend readiness could occur before Java backend endpoints were usable, so backend `/ready` probes were run from inside the frontend container.
- Concurrent Compose/Aspire validation required preserving Compose relative bind-mount semantics with `--project-directory`.

### Tester

Observed evidence:

- The issue #10 tester dispatch script required a fresh tester session, skill visibility checkpoint, independent strategy, and explicit statement that the skill is guidance rather than evidence.
- PR #11 human merge approval records that independent tester validation passed with fresh evidence and covered authentication, account, balance, contacts, transaction history, unique transaction, persistence, isolation, negative validation, cleanup, and active skill unchanged.

Inference:

- Tester use aligned most strongly with the Validation Checklist and Failure Modes references.
- The strongest tester value was not new implementation guidance; it was the requirement to challenge developer evidence and prevent false positives from stale or wrong resources.

## 8. Guidance That Worked Effectively

| Finding | Evidence | Role | Current Coverage | Classification | Recommended Action |
| --- | --- | --- | --- | --- | --- |
| Freezing the 07A baseline prevented accidental mutation of Compose input. | `SKILL.md`; issue #10; PR #11 scope; 07B README | Architect, Developer | Baseline Freeze And Repository Boundaries | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Image-only Aspire container resources were the right model for pinned polyglot services. | `references/aspire-modeling.md`; AppHost.cs; PR #11 | Architect, Developer | Project Reference Versus Container Resource | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Endpoint exposure discipline preserved loopback-only frontend and unexposed internals. | `references/aspire-modeling.md`; AppHost.cs; validator host exposure check | Architect, Developer, Tester | Host Publishing Discipline | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Validator avoided image-digest-only false positives by requiring Aspire/DCP labels and one shared creator identity. | `SKILL.md`; `references/validation-checklist.md`; `validate-aspire.ps1`; validation results | Developer, Tester | Mandatory Validation Requirements | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Functional validation went beyond health checks with login and deterministic deposit evidence. | `references/validation-checklist.md`; PR #9 correction; `validate-compose.sh`; `validate-aspire.ps1` | Developer, Tester | Functional Equivalence Validation | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Optional load generator remained disabled by default. | `references/compose-inventory.md`; AppHost.cs; 07B README | Architect, Developer | Optional-service guidance | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Secret handling stayed local and untracked. | `SKILL.md`; `generate-jwt-keys.sh`; `.gitignore`; validation results | Architect, Developer, Tester | Secrets And Credentials | ALREADY COVERED EFFECTIVELY | Keep unchanged. |
| Independent review was required before human merge. | `SKILL.md`; issue #10; tester dispatch script; PR #11 approval | Tester | Independent Review | ALREADY COVERED EFFECTIVELY | Keep unchanged. |

## 9. Failure Modes Prevented

The skill helped prevent:

- modifying the frozen 07A baseline during 07B;
- copying a previous AppHost instead of modeling Bank of Anthos;
- converting pinned polyglot services into inappropriate project references;
- adding ServiceDefaults to prebuilt non-.NET application images;
- overexposing databases and backend services;
- relying on generic frontend or process-state checks;
- validating stale Compose containers by image digest;
- treating developer evidence as final without independent challenge;
- committing generated JWT material, cookies, logs, dumps, or validation state.

These are supported by the active skill text, PR #11 skill-reuse section, AppHost code, validation script, validation results, and PR #11 human merge approval.

## 10. Additional Discovery Required

Repository-specific discovery remained necessary for:

- exact Bank of Anthos services, images, ports, credentials, and service API environment values;
- the need to preserve `HOSTNAME` values for Java services;
- local runtime differences for tracing, metrics, Java processor metrics, and JVM container support;
- whether PostgreSQL instances should remain image-pinned containers rather than Aspire-native resources;
- deterministic transaction details and SQL evidence for the deposit workflow;
- Compose relative bind-mount behavior during concurrent isolation validation;
- exact cleanup and full reset commands for both Compose and Aspire runs.

These should not be copied into the generic skill as Bank of Anthos instructions.

## 11. Incomplete or Ambiguous Guidance

| Finding | Evidence | Role | Current Coverage | Classification | Recommended Action |
| --- | --- | --- | --- | --- | --- |
| The skill says preserve environment variables and service discovery, but it does not explicitly call out container runtime assumptions that may be hidden in hostname, command, working directory, user, or language runtime flags. | 07A README Known Differences; AppHost.cs `HOSTNAME` and Java env; PR #11 skill reuse evidence | Architect, Developer | Partially covered by Compose Inventory and Aspire Modeling | REUSABLE SKILL IMPROVEMENT CANDIDATE | Add generalized runtime-assumption checklist item. |
| Stateful validation is covered, but the skill could be clearer that state should survive a controlled AppHost stop/start with storage preserved when the baseline requires persistence. | Issue #10 acceptance criteria; 07B validation-results.md; PR #11 approval | Developer, Tester | Partially covered by Stateful Dependency Validation | REUSABLE SKILL IMPROVEMENT CANDIDATE | Add explicit controlled restart guidance. |
| Relative bind-mount and project-directory semantics are inventoried but not highlighted for copied or temporary Compose files used in concurrent validation. | PR #11 skill reuse evidence; 07B validation-results.md concurrent Compose command with `--project-directory` | Developer, Tester | Partially covered by Compose Inventory volumes | REUSABLE SKILL IMPROVEMENT CANDIDATE | Add validation note for relative paths and project directory. |
| Full issue-comment timelines were not fully available through the connector during this review. | GitHub connector returned PR comments and issue bodies; issue-comment searches did not expose full issue #10 timeline | Reviewer | Not a skill topic | INSUFFICIENT EVIDENCE | Treat PR body/comments, repository files, and scripts as primary evidence; operator may review full issue timeline separately. |

## 12. Bank of Anthos-Specific Findings

| Finding | Evidence | Role | Current Coverage | Classification | Recommended Action |
| --- | --- | --- | --- | --- | --- |
| Java ledger services required Kubernetes-style `HOSTNAME` values such as `balancereader-local-1`. | 07A README; AppHost.cs; PR #11 | Developer | Generic env preservation exists | BANK OF ANTHOS SPECIFIC | Keep names in experiment docs only. |
| Tracing and metrics were disabled for local parity because pinned images expected GCP runtime metadata. | 07A README; 07B README; AppHost.cs | Architect, Developer | Generic local-runtime differences | BANK OF ANTHOS SPECIFIC | Do not generalize GCP/Stackdriver details. |
| The deterministic deposit validation used seeded Bank of Anthos account/routing values and ledger SQL. | `validate-compose.sh`; `validate-aspire.ps1` | Developer, Tester | Generic functional workflow guidance | BANK OF ANTHOS SPECIFIC | Keep workflow specifics local. |
| Two independent PostgreSQL images and volume names were required for accounts and ledger. | issue #10; AppHost.cs; 07B README | Architect, Developer | Generic stateful resource guidance | BANK OF ANTHOS SPECIFIC | Do not add service names or volume names to skill. |

## 13. DevClaw Workflow and Tooling Findings

| Finding | Evidence | Role | Current Coverage | Classification | Recommended Action |
| --- | --- | --- | --- | --- | --- |
| Worker dispatch scripts repeatedly enforced clean worktrees, idle workers, labels, and human gates. | issue #10 workflow scripts in AI Operations Platform | All roles | Not migration methodology | DEVCLAW WORKFLOW OR TOOLING | Keep out of skill. |
| GitHub token broker and Gateway calls were operational workflow mechanics. | issue #10 workflow scripts | All roles | Not migration methodology | DEVCLAW WORKFLOW OR TOOLING | Keep out of skill. |
| Active skill readability and fresh-session checks were enforced by orchestration scripts, not by migration methodology. | issue #10 workflow scripts | All roles | Not migration methodology | DEVCLAW WORKFLOW OR TOOLING | Keep out of skill. |

## 14. Reusable Skill Improvement Candidates

### Candidate 1: Container Runtime Assumptions

Target: `references/compose-inventory.md` and `references/aspire-modeling.md`.

Problem: The skill captures environment variables, command, entrypoint, and service discovery, but Experiment 07 showed that values that look incidental can be required by prebuilt images.

Evidence: 07A README records Java runtime differences; AppHost.cs preserves `HOSTNAME` and Java runtime flags; PR #11 states `HOSTNAME` preservation required independent discovery.

Generalized proposed guidance: During inventory, identify container runtime assumptions that may be parsed by the application or language runtime, including hostname, working directory, user/group, command, entrypoint, environment-derived pod/container identity, and runtime flags. Preserve or explicitly test any approved difference.

Expected benefit: Reduces rediscovery for image-based migrations and prevents startup failures caused by dropped runtime identity assumptions.

Overfitting risk: Low if stated without Bank of Anthos names, Java-specific values, or GCP metadata details.

Explicitly excluded content: Bank of Anthos hostnames, Java flag values, image digests, account data, or GCP-specific metrics details.

### Candidate 2: Controlled Stateful Restart

Target: `references/validation-checklist.md`.

Problem: Stateful validation is present but could be more actionable for Compose-to-Aspire migrations where persistence equivalence is a key acceptance criterion.

Evidence: Issue #10 required persistence across controlled Aspire shutdown and restart; validation-results.md records durable deposit evidence and preserved volumes; PR #11 approval cites controlled AppHost shutdown/restart evidence.

Generalized proposed guidance: For stateful dependencies, validate application data across a controlled AppHost stop/start that preserves configured storage, then separately document full reset behavior. Do not treat volume existence alone as durable application evidence.

Expected benefit: Prevents false confidence from initial seed data or volume presence.

Overfitting risk: Low; applies to databases, queues, object stores, and caches when persistence is in scope.

Explicitly excluded content: Bank of Anthos SQL, transaction values, volume names, and account/routing identifiers.

### Candidate 3: Relative Bind-Mount and Project-Directory Semantics

Target: `references/compose-inventory.md` or `references/validation-checklist.md`.

Problem: Concurrent validation sometimes uses copied or temporary Compose files. Relative bind mounts can silently point at different files if the Compose project directory changes.

Evidence: PR #11 notes Compose tmp/project-directory handling required local discovery; validation-results.md records using `--project-directory experiments/07-bank-of-anthos/01-kubernetes-to-compose` with a temporary Compose file so key mounts remained equivalent.

Generalized proposed guidance: When creating temporary Compose overrides or concurrent comparison runs, preserve Compose relative path resolution by using the original project directory or by explicitly materializing equivalent bind-mount paths.

Expected benefit: Prevents false failures or false passes caused by missing config, secrets, or bind-mounted assets.

Overfitting risk: Medium if expressed as a mandatory concurrent-run method; low if framed as a check when temporary Compose files or overrides are used.

Explicitly excluded content: The Bank of Anthos temporary file path, project name, key filenames, or local directory layout.

## 15. Recommendations Excluded From the Skill

The following are intentionally excluded from generic skill changes:

- Bank of Anthos service names, image digests, environment values, hostnames, credentials, seeded account/routing values, SQL queries, and volume names.
- DevClaw labels, worker names, session keys, workflow scripts, token broker operations, Gateway calls, issue numbers, and PR numbers.
- The one-time 07A operator recovery from publishing failure.
- Any instruction to create, apply, reject, or quarantine a skill proposal.
- Any requirement that every migration must use Bank of Anthos-style database or JWT validation.

| Finding | Evidence | Role | Current Coverage | Classification | Recommended Action |
| --- | --- | --- | --- | --- | --- |
| 07A publishing recovery after workflow credential/API fallback limits was a historical operator action, not migration guidance. | PR #9 operator recovery comment; issue #8 workflow assets | Developer | Not migration methodology | ONE-TIME OPERATIONAL WORKAROUND | Keep out of skill. |
| The exact temporary Compose file path used for concurrent validation was useful local evidence but should not become normative guidance. | 07B validation-results.md | Developer, Tester | Generic isolation guidance exists | ONE-TIME OPERATIONAL WORKAROUND | Generalize only the relative-path/project-directory lesson. |

## 16. Overfitting and Scope Risks

The main overfitting risk is converting application-specific runtime details into mandatory migration rules. The bounded candidates avoid that by describing the pattern, not the Bank of Anthos values.

The second risk is making the skill longer without improving outcomes. The current skill is already strong. Any update should be short and targeted, preferably one or two bullets in existing references rather than a new reference file or a redesign.

## 17. Decision

`TARGETED SKILL UPDATE RECOMMENDED`

Rationale: The current skill worked effectively and prevented meaningful failure modes. The evidence does not justify redesign. However, Experiment 07 produced three reusable, non-Bank-of-Anthos patterns that can be expressed generically and would likely reduce future investigation or prevent validation defects.

Classification counts:

| Classification | Count |
| --- | ---: |
| ALREADY COVERED EFFECTIVELY | 8 |
| REUSABLE SKILL IMPROVEMENT CANDIDATE | 3 |
| BANK OF ANTHOS SPECIFIC | 4 |
| DEVCLAW WORKFLOW OR TOOLING | 3 |
| ONE-TIME OPERATIONAL WORKAROUND | 2 |
| INSUFFICIENT EVIDENCE | 1 |

The two one-time operational workaround findings are the 07A operator publishing recovery and the exact temporary Compose file path used for concurrent validation. The latter supports a reusable bind-mount/project-directory improvement, but the exact path and command form should remain historical evidence only.

## 18. Bounded Next-Step Recommendation

Open a separate, explicitly approved skill-update issue in `DimitryZH/ai-operations-platform` only if the operator accepts this review decision. That future issue should prepare a pending proposal, not directly edit the active skill, and should limit itself to the three candidate changes above.

Do not create a Skill Workshop proposal from this review PR. Do not modify the active `compose-to-aspire-migration` skill as part of Experiment 07 documentation.

# Application Modernization Lab

**AI-agent-driven experiments for migrating multi-service applications from Docker Compose to .NET Aspire.**

This repository is a research lab that evaluates how AI coding agents and agent-orchestration workflows can plan, implement, validate, and improve application-modernization work across progressively more complex systems.

The experiments began with direct Codex-driven migrations and later evaluated OpenClaw/DevClaw role-based orchestration, GitHub-native task state, explicit human review, and operator-approved reusable migration knowledge. The evaluated OpenClaw/DevClaw architecture was not selected as the primary AI Operations Platform orchestrator, while useful governance patterns and successful application-modernization results remain preserved.

## What This Repository Demonstrates

- Docker Compose to .NET Aspire migration across increasing levels of complexity;
- functional-equivalence validation rather than configuration translation alone;
- preservation of service dependencies, messaging, persistence, health checks, and observability;
- AI-assisted architecture analysis, implementation, testing, and review;
- remote agent execution on a controlled Linux DevBox;
- GitHub-based task orchestration, auditability, and human-in-the-loop approvals;
- migration patterns that can be promoted into operator-approved reusable skills.

## Experiment Progression

| Experiment | Scope | Agent / Execution Model | Result |
|---|---|---|---|
| 01 | Controlled multi-service demo | Codex-assisted migration | PASS |
| 02 | Browser-constrained open-source migration | Codex in a constrained environment | 6/10 |
| 03 | Docker Example Voting App | Codex desktop workflow | 8/10 |
| 04 | Google Cloud DevBox execution validation | Codex on a remote Linux DevBox | PASS - 95/100 |
| 05 | Full OpenTelemetry Demo / Astronomy Shop migration | Codex on a controlled DevBox | PASS - 94/100 |
| 06 | Online Boutique modernization | OpenClaw + DevClaw + OpenAI GPT-5.5 | PASS - Docker Compose baseline and .NET Aspire migration independently validated; reusable migration skill applied |
| 07 | Bank of Anthos modernization | OpenClaw + DevClaw + OpenAI GPT-5.5 | PASS - Docker Compose baseline and .NET Aspire migration independently validated; [skill knowledge review](experiments/07-bank-of-anthos/compose-to-aspire-skill-knowledge-review.md) recommends a targeted skill update |
| 08 | AKS Store Demo modernization | Compose baseline, Aspire migration, and orchestration retrospective | PASS - accepted Compose baseline and successful .NET Aspire migration; [retrospective](experiments/08-aks-store-demo/retrospective.md) separates migration success from OpenClaw/DevClaw primary-orchestrator non-selection |

## Agent-Orchestration Track

Experiments 06, 07, and 08 evaluated more than individual coding-agent output. They tested a multi-agent workflow in which:

- **OpenClaw** provides the operator-facing control surface and agent runtime;
- **DevClaw** manages projects, roles, task state, worker sessions, and review state;
- **OpenAI GPT-5.5** performs reasoning within architect and engineering sessions;
- **GitHub Issues, labels, comments, branches, and pull requests** provide durable workflow state and an auditable evidence trail;
- the **human operator** approves architecture, implementation, merge, and reusable knowledge promotion.

```mermaid
flowchart LR
    Human[Human Operator]
    UI[OpenClaw Control UI]
    DevClaw[DevClaw Orchestrator]
    Agents[Role-based Agent Sessions]
    Workspace[Controlled DevBox Workspace]
    GitHub[GitHub Issues, Labels, Comments and PRs]
    Skill[Operator-Approved Workspace Skill]

    Human --> UI
    UI --> DevClaw
    DevClaw --> Agents
    Agents --> Workspace
    Agents --> GitHub
    GitHub --> Human
    Human -. approval .-> DevClaw
    GitHub -. validated evidence .-> Skill
    Human -. explicit apply .-> Skill
```

This design separates AI reasoning from execution policy. Agents can investigate and propose changes, but workflow transitions and higher-impact actions remain bounded by explicit operator decisions.

The historical experiments preserved useful governance patterns: GitHub-native auditability, role separation, architecture-first planning, immutable baselines, validation-first delivery, and explicit human approval gates. Those patterns survive independently of the worker runtime.

The final Experiment 08 retrospective records the bounded orchestration conclusion: the evaluated OpenClaw/DevClaw worker architecture was not selected as the primary AI Operations Platform orchestration foundation. OpenClaw/DevClaw is not rejected in all roles, OpenClaw may remain an optional communication gateway or interactive runtime subject to separate validation, and the successful Experiment 06, 07, and 08 application-modernization outcomes remain valid.

## Highlight: Experiment 05

Experiment 05 migrated the full OpenTelemetry Demo, also known as Astronomy Shop, from Docker Compose to .NET Aspire.

### Migration Scope

- 29 services represented in Aspire;
- Kafka messaging preserved;
- OpenTelemetry Collector preserved;
- Jaeger, Prometheus, Grafana, and OpenSearch preserved;
- application and observability topology retained;
- functional and operational validation performed on the complete environment.

### Validation Summary

```text
29/29 services migrated
No unresolved MIGRATION_FAILURE
Final score: 94/100
```

The validation covered:

- storefront and checkout workflows;
- Kafka producer and consumer paths;
- distributed tracing;
- metrics and logging pipelines;
- observability dashboards and backends;
- service topology and runtime behavior.

## Key Findings

### AI agents can perform meaningful modernization work

The experiments show that AI-assisted workflows can migrate realistic multi-service applications when the task includes architecture analysis, implementation, verification, and evidence-based review.

### Functional equivalence matters more than syntax conversion

A successful migration must preserve runtime behavior, dependencies, state, health semantics, messaging, and operational visibility, not merely recreate service declarations in another format.

### Observability and messaging can be preserved

Complex OpenTelemetry and Kafka-based systems can be represented in Aspire without discarding their original operational model.

### Controlled remote execution improves reliability

A dedicated Linux DevBox provides a more reproducible environment than browser-constrained execution and supports stronger validation, credential boundaries, and runtime inspection.

### Agent orchestration adds governance

The OpenClaw/DevClaw track tested whether role separation, GitHub-native workflow state, and human approvals can make agent-driven modernization safer, more reviewable, and easier to reuse across projects. The retained governance patterns remain useful even though the evaluated OpenClaw/DevClaw architecture was not selected as the primary AI Operations Platform orchestrator.

## Repository Structure

```text
.
|-- AGENTS.md
|-- experiments/
|   |-- 01-controlled-demo/
|   |-- 02-open-source-voting-app/
|   |-- 03-codex-desktop-voting-app/
|   |-- 04-google-cloud-devbox/
|   |-- 05-opentelemetry-demo/
|   |-- 06-online-boutique/
|   |-- 07-bank-of-anthos/
|   `-- 08-aks-store-demo/
|-- LICENSE
`-- README.md
```

Each experiment contains its own source material, Aspire implementation, validation evidence, and conclusions.

## Recommended Reading

1. Experiment 05 final assessment;
2. Experiment 05 equivalence review;
3. Experiment 04 DevBox validation;
4. Experiment 03 Voting App migration;
5. Experiment 06 Online Boutique migration and validation results;
6. Experiment 07 Bank of Anthos skill knowledge review;
7. Experiment 08 AKS Store Demo retrospective.

## Technical Value

This lab demonstrates practical experience in:

- .NET Aspire and distributed application orchestration;
- Docker Compose modernization;
- polyglot microservice systems;
- OpenTelemetry, Prometheus, Grafana, Jaeger, and OpenSearch;
- Kafka, PostgreSQL, Redis, and containerized dependencies;
- AI coding agents and multi-agent orchestration;
- human-in-the-loop workflow design;
- cloud-hosted agent execution;
- validation-driven engineering and technical documentation.

## Conclusion

Application Modernization Lab documents the evolution from small AI-assisted migrations to controlled, auditable workflows for complex application modernization.

The central question is no longer only whether an AI agent can generate an Aspire AppHost. The broader experiment evaluates whether specialized agents and replaceable execution models can preserve system behavior, produce reviewable evidence, and improve future migrations through operator-approved knowledge reuse.

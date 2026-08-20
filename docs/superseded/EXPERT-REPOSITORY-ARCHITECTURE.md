# Expert Repository Architecture

> ⚠ **SUPERSEDED (2026-08-18).** **[`ARCHITECTURE.md`](../../ARCHITECTURE.md) is authoritative** — it is
> measured rather than asserted, and it postdates this file. Retained for the original framing only;
> **do not cite it for structure or state.**
> ⭐ **Navigation starts at [`START-HERE.md`](../../START-HERE.md).**

## Purpose

This repository is a customer-engineering operating system, not a folder of notes. It separates knowledge, execution, evidence, delivery, and career outputs so each claim has a path to verification.

## Five planes

### 1. Knowledge plane

Concepts, official resources, unofficial explanations, glossary, certification maps, fundamentals, intermediate depth, mastery notes, and misconceptions.

### 2. Execution plane

Labs, scripts, Bicep/Terraform, PowerShell, Graph calls, migration factories, test data, setup, verification, cleanup, and repeatability.

### 3. Failure and operations plane

Deliberately broken environments, incidents, tickets, logs, monitoring, SLOs, runbooks, RCA, rollback, backup, restore, and DR.

### 4. Customer-delivery plane

Discovery, current-state assessment, requirements, HLD, LLD, ADR, risk register, configuration checklist, pilot, test plan, cutover, rollback, handover, training, and executive communication.

### 5. Career-evidence plane

Portfolio case studies, resume map, interview defense, role maps, sanitized evidence, verified skill matrix, and honest status.

## Domain architecture

Each domain follows this order:

```text
business problem → fundamentals → architecture → implementation → integration → failure → security → operations → customer delivery → evidence
```

## Domain boundaries

- `00-foundations/` — transferable computing, OS, CLI, APIs, Git, troubleshooting.
- `10-networking/` — packet flow, DNS, TLS, routing, Azure connectivity.
- `20-azure-platform/` — governance, IaC, landing zones, cost, deployment.
- `30-identity-and-nhi/` — workforce and non-human identities.
- `35-active-directory-and-hybrid-identity/` — AD, Connect, Cloud Sync, ADFS, federation.
- `40-microsoft-365-platform/` — Exchange, SharePoint, OneDrive, Teams, Groups, Viva, Power Platform.
- `45-m365-migration-engineering/` — assessment, migration factories, tools, cutover, reconciliation.
- `50-security-operations/` — Defender, Sentinel, KQL, Purview, detection, response.
- `60-ai-and-secure-ai/` — AI workload, data, agent, NHI, safety, evaluation.
- `70-operations-and-reliability/` — monitoring, SLOs, incidents, recovery, service management.
- `75-architecture-and-consulting/` — customer engagement and technical documentation.
- `80-customer-scenarios/` — industry-specific cases.

## Navigation rule

A reviewer should reach a finished case study in three clicks:

```text
README → flagship case → evidence / architecture / lab / outcome
```

A learner should reach a runnable lab in four clicks:

```text
README → domain → topic → lab README → setup
```

## Truth rule

The repository distinguishes `research`, `lab-planned`, `lab-verified`, `operated`, `customer-ready`, and `production-verified`. A resource link is not implementation evidence. A generated script is not independent engineering evidence until it has been understood, tested, reviewed, and safely executed.

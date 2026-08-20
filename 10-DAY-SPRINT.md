# Ten-Day M365, Azure, Security and Migration Sprint

This is an implementation sprint, not a claim of complete mastery. Work 8–10 focused hours per day with breaks, cost controls, and cleanup. Every day ends with evidence, a teach-back, and an honest gap log.

> **The day files are authoritative.** This page is the overview; execute from
> [`DAILY-EXECUTION/`](DAILY-EXECUTION/). **[DAY-01](DAILY-EXECUTION/DAY-01.md) sets the standard**
> every other day is written to: real commands with real parameters, the permission each needs,
> expected output, the actual error text of each failure, cost, and cleanup.
>
> ⚠ **Known gap, surfaced 2026-08-09.** This page previously listed Day 2 as *"Networking and
> secure Azure access"*, but **no day file covers networking** — the ten days are M365, identity,
> migration and security. Azure networking lives in the `10-networking/` topic folders, which
> `COVERAGE.md` reports as unwritten. This overview has been corrected to match the day files; the
> networking gap is real and remains open.
>
> **This sprint is not an SC-300 study plan.** If the goal is the **2026-08-28 SC-300 exam**, use
> [SC-300-EXAM-READINESS.md](SC-300-EXAM-READINESS.md) as the control tower and
> [SC-300-SPRINT/README.md](SC-300-SPRINT/README.md) as the command source of truth. This 10-day
> pack is the post-SC-300 M365, migration, security, and customer-delivery breadth track. The two
> tracks share concepts, but they are not the same qualification.

## Day 1 — Baseline and architecture foundations

Set up Azure CLI, PowerShell, Microsoft Graph, Bicep/Terraform conventions, logging, tags, budgets, cleanup, and evidence standards. Review TCP/IP, DNS, TLS, identity boundaries, control plane/data plane, and the Decision Stack.

Deliver: baseline, architecture template, cost guardrails, command journal.

## Day 2 — Exchange Online, mail flow, and email security

Exchange Online, accepted domains, connectors, transport rules, SMTP relay, and the three DNS records that decide whether your mail is trusted — SPF, DKIM, DMARC, and why DMARC checks *alignment* rather than pass/fail. Trace a real message from its internet headers.

Deliver: mail-flow diagram from real headers, DMARC rollout plan with gates, relay ADR, failure tickets.

## Day 3 — Collaboration governance

SharePoint, OneDrive, Teams, and M365 Groups. Tenant sharing ceiling versus site settings, guest inventory, ownerless groups, retention versus deletion — and finding the oversharing that Copilot will surface.

Deliver: sharing posture report, guest and ownerless-group inventory, lifecycle policy, SOPs.

## Day 4 — AD, Entra and hybrid identity

Build identity flows around AD concepts, Entra Connect/Cloud Sync, PHS/PTA/federation, ADFS dependencies, source anchor, soft/hard match, certificates, staging, and rollback. Include Okta as an identity-provider integration pattern.

Deliver: hybrid identity decision tree, failure lab, migration runbook.

## Day 5 — M365 discovery and assessment

Create an assessment process for users, groups, domains, devices, apps, mailboxes, sites, OneDrive, Teams, Power Platform, licenses, permissions, data, dependencies, and risks.

Deliver: discovery questionnaire, inventory schema, dependency map, current-state report.

## Day 6 — Migration tools and factory design

Research and compare Microsoft-native tools, BitTitan MigrationWiz, Quest On Demand, ShareGate, Cloudiway, AvePoint, and Xillio. Build a tool-selection matrix. Clearly label research, trial, and personally verified experience.

Deliver: migration tool matrix, limitations register, pilot-wave plan.

## Day 7 — Google Workspace to M365 and tenant-to-tenant

Design two migration factories: Google Workspace to M365 and M365 tenant-to-tenant. Cover identity, domain, coexistence, mailbox, Drive/OneDrive, SharePoint, Teams, devices, applications, cutover, rollback, validation, and hypercare.

Deliver: HLD, LLD, migration plan, communication plan, rollback plan.

## Day 8 — Exchange hybrid and collaboration migration

Assess Exchange hybrid, connectors, Autodiscover, OAuth, free/busy, relay, public folders, throttling, SharePoint/OneDrive/Teams permissions, links, owners, and reconciliation.

Deliver: hybrid troubleshooting tickets, configuration checklist, reconciliation report, operations manual.

## Day 9 — Security, NHI, automation and AI

Implement least privilege, Conditional Access, PIM, Key Vault, managed identity, workload federation, Defender/Sentinel/KQL, Purview, and a secure AI/RAG data-flow design. Add Terraform/Bicep/PowerShell automation where practical.

Deliver: NHI register, detection pack, secure AI threat model, automation evidence.

## Day 10 — Customer delivery and interview defense

Run discovery for finance, healthcare, SaaS, retail, manufacturing, government, and nonprofit scenarios. Produce HLD/LLD, risk register, test plan, cutover runbook, handover, executive summary, and a customer workshop.

Deliver: final evidence index, customer case packs, teach-back, readiness report, next-gap list.

## Daily closeout

- What was built and verified?
- Which command/configuration was used and why?
- What happened behind the scenes?
- What broke and how was it diagnosed?
- What are the security, cost, reliability, compliance, and migration implications?
- What would change for a larger or regulated customer?
- Is the work reproducible, supportable, and safely cleanable?

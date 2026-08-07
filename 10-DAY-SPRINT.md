# Ten-Day M365, Azure, Security and Migration Sprint

This is an implementation sprint, not a claim of complete mastery. Work 8–10 focused hours per day with breaks, cost controls, and cleanup. Every day ends with evidence, a teach-back, and an honest gap log.

## Day 1 — Baseline and architecture foundations

Set up Azure CLI, PowerShell, Microsoft Graph, Bicep/Terraform conventions, logging, tags, budgets, cleanup, and evidence standards. Review TCP/IP, DNS, TLS, identity boundaries, control plane/data plane, and the Decision Stack.

Deliver: baseline, architecture template, cost guardrails, command journal.

## Day 2 — Networking and secure Azure access

Build VNet/subnets/NSGs/routes/private DNS/private endpoint and controlled outbound access. Test DNS and packet paths. Break an NSG, route, and private DNS association; diagnose and repair.

Deliver: network lab, packet-flow explanation, failure tickets, ADR.

## Day 3 — Microsoft 365 platform

Study and lab Exchange Online, mail flow, connectors, transport rules, SMTP relay, SPF/DKIM/DMARC, SharePoint, OneDrive, Teams, Groups, permissions, external sharing, retention, and service health.

Deliver: M365 tenant assessment, mail-flow diagram, collaboration governance matrix, SOPs.

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

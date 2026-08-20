# Azure Cloud Security Mastery

A hands-on Azure, Microsoft 365, cloud security, identity, non-human identity, networking, AI security, migration, and customer-engineering curriculum.

This is not an exam-notes repository. AZ-104, AZ-500, SC-300, SC-500/Cloud & AI Security, AI, and networking objectives are coverage baselines. Every capability must also be implemented, automated, broken, secured, monitored, explained, and applied to a customer scenario.

---

## Current state — read this before trusting the structure

**[`COVERAGE.md`](COVERAGE.md) is the only honest answer to "what is actually done here."**
It is **generated from the filesystem** by [`tools/Build-CoverageRegister.ps1`](tools/Build-CoverageRegister.ps1), not maintained by hand, because a hand-maintained status field always drifts.

As of the last regeneration: **0 of 144 topics meet the content contract.** 6 have concept prose with no evidence; 138 are scaffold READMEs. The directory tree describes an *intended* curriculum — **a folder existing proves nothing was studied.**

What genuinely exists today is the SC-300 → SC-500 identity track:

| Read in this order | What it is |
|---|---|
| [SC-300-EXAM-READINESS.md](SC-300-EXAM-READINESS.md) | **Control tower for the Aug 28 exam push**: what to use, what to skip, memory hooks, explain-back models, and production-readiness rules |
| [SC-300-MASTERY-SYLLABUS.md](SC-300-MASTERY-SYLLABUS.md) | The map. Every topic tagged `CORE` / `PREREQ` / `SHALLOW` / `BEYOND` / `DEAD` |
| [7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md](7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md) | Strategy overlay for the E5/Azure trial sprint: exam readiness, resume-proof evidence, and fixed-scope offers |
| [SC-300-SPRINT/README.md](SC-300-SPRINT/README.md) | Execution source of truth for the 7-day SC-300 lab sprint; use these day files for commands |
| [Layer 1 — Identity protocols](30-identity-and-nhi/oauth-oidc-saml-and-api-auth/LAYER-1-IDENTITY-PROTOCOLS.md) | OAuth flows, JWT claim-by-claim, SAML, SCIM, consent. **Start here — nothing else makes sense first** |
| [Layer 2 — User identities](30-identity-and-nhi/entra-users-and-groups/LAYER-2-DOMAIN-1-USER-IDENTITIES.md) | Tenant, identities, external, **hybrid identity** |
| [Layer 3 — Authentication & Conditional Access](30-identity-and-nhi/conditional-access/LAYER-3-DOMAIN-2-AUTH-AND-ACCESS.md) | Largest exam domain; where the daily job lives |
| [Layer 4 — Workload identities](30-identity-and-nhi/service-principals/LAYER-4-DOMAIN-3-WORKLOAD-IDENTITIES.md) | App/SP model, managed identities, **secretless federation** |
| [Layer 5 — Identity governance](30-identity-and-nhi/pim-and-access-reviews/LAYER-5-DOMAIN-4-IDENTITY-GOVERNANCE.md) | Entitlement management, PIM, access reviews, **KQL** |
| [Layer 6 — SC-500 bridge](60-ai-and-secure-ai/ai-agent-identity/LAYER-6-SC500-BRIDGE-AI-SECURITY.md) | **Entra Agent ID** and AI security |
| [Layer 7 — Industry verticals](80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md) | Nine sectors: driver, design, and the trap |
| [SC-300-RESOURCE-LIBRARY.md](SC-300-RESOURCE-LIBRARY.md) | Eight tiers — RFCs, Microsoft, Okta/Auth0, offensive research, tooling |
| [Seed-LabTenant.ps1](30-identity-and-nhi/entra-users-and-groups/Seed-LabTenant.ps1) | Builds a realistic lab tenant. Dry-run by default |

Layers 1–6 are verified against live Microsoft documentation. Layer 7 is labelled inside the document as consulting judgement, not verified product behaviour.

**~40 labs are defined across those layers and none have been run.** Documented is not the same as practised, and this repo should never imply otherwise.

---

## Target capability

The goal is to become able to support customers across industries: discover requirements, assess an environment, design a solution, implement it, migrate safely, troubleshoot failures, secure it, document it, train users, and hand it over for operation.

## Capability pillars

- Azure administration, governance, compute, storage, networking, monitoring, backup, and recovery.
- Microsoft 365: Exchange Online, hybrid Exchange, SharePoint Online, OneDrive, Teams, Groups, Viva, Power Platform, mail flow, relay, hygiene, and tenant architecture.
- Identity and hybrid identity: Active Directory, Entra ID, Entra Connect, Cloud Sync, ADFS, federation, Okta, SSO, lifecycle governance, and access management.
- Non-human identities: app registrations, service principals, managed identities, workload identity federation, Key Vault, OAuth/OIDC/SAML, SCIM, ownership, rotation, and incident response.
- Migration engineering: discovery, assessment, inventory, dependency mapping, coexistence, pilot waves, cutover, rollback, reconciliation, and decommissioning.
- Migration ecosystem: Microsoft-native tools, BitTitan, Quest, ShareGate, Cloudiway, AvePoint, Xillio, and tool-selection trade-offs. Product familiarity is not claimed until personally verified.
- Security operations: Defender, Sentinel, KQL, Purview, posture management, threat hunting, vulnerability management, incident response, and audit evidence.
- Secure AI: Azure AI, Azure OpenAI, RAG, private access, agent identity, data security, prompt injection, evaluation, and governance.
- Customer delivery: discovery, HLD, LLD, configuration checklists, SOPs, migration runbooks, test plans, change plans, handover, and executive communication.

## Learning loop

**Learn → build → inspect → break → fix → secure → observe → explain → apply to a customer → document evidence.**

Every command must explain its purpose, parameters, permissions, location, control-plane effect, data-plane effect, cost, expected result, failure modes, rollback, and production implications.

## Repository map

- `00-foundations/` — computing, OS, CLI, Git, APIs, troubleshooting.
- `10-networking/` — TCP/IP, subnetting, DNS, TLS, routing, VPN, private access, Azure VNets.
- `20-azure-platform/` — governance, RBAC, Policy, ARM, Bicep, Terraform, landing zones, FinOps.
- `30-identity-and-nhi/` — workforce identity and non-human identity.
- `35-active-directory-and-hybrid-identity/` — AD, Connect, Cloud Sync, ADFS, federation, coexistence.
- `40-microsoft-365-platform/` — Exchange, SharePoint, OneDrive, Teams, Groups, Viva, Power Platform.
- `45-m365-migration-engineering/` — migration factories and migration-tool comparisons.
- `50-security-operations/` — Defender, Sentinel, KQL, Purview, detection, response.
- `60-ai-and-secure-ai/` — AI workload identity, data security, RAG, agents, evaluation.
- `70-operations-and-reliability/` — monitoring, SLOs, incidents, DR, runbooks, RCA.
- `75-architecture-and-consulting/` — discovery, HLD, LLD, design decisions, customer delivery.
- `80-customer-scenarios/` — finance, healthcare, SaaS, retail, manufacturing, government, nonprofit.
- `labs/`, `incidents/`, `migration-factories/`, `portfolio/`, `customer-delivery/` — evidence.

## Evidence rule

A topic is not complete because it was watched, read, or tested in a quiz. Completion requires a concept explanation, a reproducible lab, deliberate failure exercises, security and operations notes, customer use cases, and verified evidence. Unverified knowledge stays marked as research or developing.

Start with `START-HERE.md`, then `MASTERY-STANDARD.md`, `CURRICULUM-MAP.md`, `CERTIFICATION-MAP.md`, `RESOURCE-MAP.md`, and `10-DAY-SPRINT.md`.

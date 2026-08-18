# Azure Cloud Security Mastery

A hands-on Azure, Microsoft 365, cloud security, identity, non-human identity, networking, AI security, migration, and customer-engineering curriculum.

This is not an exam-notes repository. AZ-104, AZ-500, SC-300, SC-500/Cloud & AI Security, AI, and networking objectives are coverage baselines. Every capability must also be implemented, automated, broken, secured, monitored, explained, and applied to a customer scenario.

---

## Current state — read this before trusting the structure

**[`COVERAGE.md`](COVERAGE.md) is the only honest answer to "what is actually done here."**
It is **generated from the filesystem** by [`tools/Build-CoverageRegister.ps1`](tools/Build-CoverageRegister.ps1), not maintained by hand, because a hand-maintained status field always drifts.

As of the last regeneration: ⭐ **all 144 topics are written to [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md)** — no scaffold remains. ⭐ **But 0 of 144 carry evidence**, and that distinction is the whole point of the register:

| Measure | State | Means |
|---|---|---|
| ⭐ **Depth** | ⭐ **144/144 DEEP** | the README teaches the concept, with worked examples |
| ⭐ **Evidence** | ⭐ **0/144 WRITTEN** | ⭐ **no lab artifacts exist in the six facet folders** |

⭐ **Read that as: everything here has been written and nothing here has been performed.** Documented is not practised, and this repo should never imply otherwise.

⭐ **Where to start: [`START-HERE.md`](START-HERE.md)** — it is the single map of what to read, in what order, and why.

The spine of the curriculum is the seven Layer documents:

| Read in this order | What it is |
|---|---|
| [SC-300-MASTERY-SYLLABUS.md](SC-300-MASTERY-SYLLABUS.md) | The map. Every topic tagged `CORE` / `PREREQ` / `SHALLOW` / `BEYOND` / `DEAD` |
| [7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md](7-DAY-SC-300-E5-AZURE-TRIAL-SPRINT.md) | Emergency 7-day E5/Azure trial sprint for exam readiness plus resume-proof evidence |
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

⭐ **Every domain has its own README** with a reading order, the one thing each topic gives you, and a generated table of measured state. ⭐ **Those twelve files are the navigation layer** — start at [`START-HERE.md`](START-HERE.md) and follow them.

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

⭐ **Each domain README carries its own reading order and a generated state table. Click through.**

| Domain | What it is | ⭐ When to read it |
|---|---|---|
| [`00-foundations/`](00-foundations/) | OS, CLI, Git, APIs, troubleshooting method | ⭐ **first, once** |
| [`10-networking/`](10-networking/) | TCP/IP, DNS, TLS, routing, VNets, private endpoints | before Azure work |
| [`20-azure-platform/`](20-azure-platform/) | RBAC, Policy, ARM, IaC, landing zones, cost | before Azure labs |
| ⭐ [`30-identity-and-nhi/`](30-identity-and-nhi/) | ⭐ **the core domain — Layers 1–5 live here** | ⭐ **the main event** |
| [`35-active-directory-and-hybrid-identity/`](35-active-directory-and-hybrid-identity/) | AD, Connect, Cloud Sync, ADFS, Okta | after Layer 2 |
| [`40-microsoft-365-platform/`](40-microsoft-365-platform/) | Exchange, SharePoint, Teams, Purview, Intune | after Layers 1–3 |
| [`45-m365-migration-engineering/`](45-m365-migration-engineering/) | ⭐ **the most employable domain** | after M365 |
| [`50-security-operations/`](50-security-operations/) | Defender, Sentinel, KQL, hunting, IR | ⭐ **SC-200 phase** |
| [`60-ai-and-secure-ai/`](60-ai-and-secure-ai/) | agent identity, prompt injection, RAG, governance | ⭐ **SC-500 bridge** |
| [`70-operations-and-reliability/`](70-operations-and-reliability/) | monitoring, SLOs, incidents, backup, chaos | ⭐ **alongside everything** |
| [`75-architecture-and-consulting/`](75-architecture-and-consulting/) | discovery, HLD/LLD, cutover, handover | ⭐ **before your next interview** |
| [`80-customer-scenarios/`](80-customer-scenarios/) | nine verticals, engagement depth | before a sector meeting |

**Practice and evidence:** [`SC-300-SPRINT/`](SC-300-SPRINT/) — the runnable 7-day lab track ·
`labs/`, `incidents/`, `portfolio/`, `customer-delivery/` — where artifacts land.

## Evidence rule

A topic is not complete because it was watched, read, or tested in a quiz. Completion requires a concept explanation, a reproducible lab, deliberate failure exercises, security and operations notes, customer use cases, and verified evidence. Unverified knowledge stays marked as research or developing.

## The four files that matter

⭐ **There are 27 markdown files at the root of this repo. Four of them are load-bearing:**

| File | Why |
|---|---|
| ⭐ [`START-HERE.md`](START-HERE.md) | ⭐ **the map** — what to read, in what order, and why |
| ⭐ [`COVERAGE.md`](COVERAGE.md) | ⭐ **measured state, generated** — the only honest answer to "what's done" |
| ⭐ [`RETENTION.md`](RETENTION.md) | ⭐ **the memory layer** — hooks, numbers, interview answers |
| [`CONTENT-STANDARD.md`](CONTENT-STANDARD.md) | what "written" means, and the exemplar to match |

Reference, when you need them: [`CERT-MAP.md`](CERT-MAP.md) (six certifications) ·
[`ARCHITECTURE.md`](ARCHITECTURE.md) (how the repo is built) ·
[`SC-300-MASTERY-SYLLABUS.md`](SC-300-MASTERY-SYLLABUS.md) ·
[`SC-300-RESOURCE-LIBRARY.md`](SC-300-RESOURCE-LIBRARY.md).

⚠ Several root files carry a **SUPERSEDED** banner naming the file that replaced them. ⭐ **Trust the
banner** — they are kept for history, not for reading.

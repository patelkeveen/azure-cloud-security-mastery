# Azure Cloud Security Mastery

A hands-on Azure, Microsoft 365, cloud security, identity, non-human identity, networking, AI security, migration, and customer-engineering curriculum.

This is not an exam-notes repository. AZ-104, AZ-500, SC-300, SC-500/Cloud & AI Security, AI, and networking objectives are coverage baselines. Every capability must also be implemented, automated, broken, secured, monitored, explained, and applied to a customer scenario.

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

Start with `CURRICULUM-MAP.md`, then `RESOURCE-MAP.md`, then `10-DAY-SPRINT.md`.

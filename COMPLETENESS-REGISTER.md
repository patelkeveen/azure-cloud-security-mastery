# Completeness Register

> ⚠ **SUPERSEDED as the authoritative inventory (2026-08-10).**
> **[`COVERAGE.md`](COVERAGE.md) is authoritative** — it is *generated* from the filesystem by
> `tools/Build-CoverageRegister.ps1`, so it cannot overstate the repository. This file is
> hand-maintained and will drift, always optimistically. Retained for the status vocabulary and
> historical intent; **do not cite it for coverage claims.** See [`ARCHITECTURE.md`](ARCHITECTURE.md) §7.


This is the authoritative inventory for the repository. A row is complete only when concept, implementation, break/fix, security, operations, customer use case, and evidence exist.

## Status vocabulary

- `INDEXED` — named in the curriculum.
- `RESEARCH` — official and supplemental resources collected.
- `LAB-PLANNED` — lab design exists, not yet executed.
- `LAB-VERIFIED` — personally executed and evidence retained.
- `OPERATED` — monitored, broken, repaired, and documented.
- `CUSTOMER-READY` — customer artifacts and industry cases complete.

Never use `PRODUCTION` unless the work was genuinely performed in production.

## Foundations

- Computing, hardware, operating systems, processes, filesystems, permissions
- Linux administration and troubleshooting
- Windows administration and PowerShell
- CLI, Git, GitHub, APIs, JSON, authentication, scripting
- Virtualization, containers, package management
- Troubleshooting methodology and technical writing

## Networking

- OSI/TCP-IP, IPv4/IPv6, CIDR, subnetting, ARP, ICMP, TCP, UDP
- HTTP/S, REST, headers, cookies, proxies, load balancers
- DNS, DHCP, NAT, routing, default routes, BGP awareness
- Firewalls, security groups, NACLs, segmentation, DMZ
- TLS, PKI, certificate issuance, expiry, renewal, revocation
- Azure VNet, subnets, NSGs, UDRs, peering, hub-spoke
- VPN, ExpressRoute, private endpoints, private DNS, Azure Firewall
- Application Gateway, Front Door, Load Balancer, WAF
- Network monitoring, flow logs, packet-path and DNS troubleshooting

## Azure platform and governance

- Tenant, subscriptions, management groups, resource groups
- ARM, tags, locks, RBAC, Azure Policy, initiatives and exceptions
- Budgets, quotas, Advisor, cost allocation, FinOps and chargeback
- Azure Resource Graph, service health, support boundaries
- Bicep, Terraform, state, modules, plan/what-if, drift and rollback
- Landing zones, connectivity, identity, management and security baselines
- Deployment strategies, approvals, change control and release management

## Workforce identity

- Entra users, groups, administrative units and custom domains
- Authentication methods, MFA, passwordless, passkeys and Windows Hello
- Conditional Access, report-only, policy interactions and emergency access
- Identity Protection, user risk, sign-in risk and investigation
- PIM for roles, groups and Azure resources
- Access reviews, entitlement management and lifecycle workflows
- External identities, B2B, cross-tenant access, guests and sponsors
- RBAC, least privilege, access packages and governance evidence

## Non-human identities

- App registrations, enterprise applications and service principals
- Application permissions, delegated permissions, consent and owners
- System-assigned and user-assigned managed identities
- Workload identity federation and OIDC
- GitHub Actions, Azure DevOps, Functions, App Service, VMs and AKS identity
- Key Vault secrets, keys, certificates and access policies/RBAC
- Credential rotation, expiry, revocation and emergency containment
- SCIM, OAuth 2.0, OIDC, SAML, API authentication and token handling
- NHI inventory, ownership, lifecycle, attack paths and incident response
- AI agents, tools and data sources as non-human identities

## Active Directory and hybrid identity

- AD DS, domains, forests, trusts, DNS, Kerberos, LDAP and Group Policy
- Entra Connect Sync, Cloud Sync, PHS, PTA and federation
- ADFS, certificates, claims, endpoints and dependency troubleshooting
- Source anchor, immutable ID, soft match, hard match and duplicate objects
- Connect Health, staging mode, swing migration and rollback
- Hybrid coexistence, domain changes, tenant consolidation and M&A
- Okta and other identity-provider integration patterns

## Microsoft 365 platform

- Exchange Online, Exchange Server and hybrid Exchange
- Mail flow, connectors, transport rules, SMTP relay and applications
- Autodiscover, OAuth, free/busy, public folders and mailboxes
- SPF, DKIM, DMARC, anti-spam, anti-phishing and mail hygiene
- SharePoint architecture, sites, hubs, permissions, sharing and storage
- OneDrive, sync, external sharing, ownership and lifecycle
- Teams, policies, channels, meetings, external access, voice awareness
- Microsoft 365 Groups, naming, expiration, owners and governance
- Viva awareness and adoption
- Power Platform environments, DLP, connectors, service accounts and CoE awareness
- Licensing, service limits, throttling, service health and support escalation
- Purview retention, sensitivity labels, DLP, eDiscovery and audit
- Intune, Autopilot, device compliance and endpoint migration
- Windows 365 and Azure Virtual Desktop awareness

## M365 migration engineering

- Discovery, assessment, inventory and dependency mapping
- User, domain, group, license, mailbox, device, app and data inventory
- Data classification, permissions, ownership and risk remediation
- Google Workspace to M365
- Tenant-to-tenant M365
- Exchange Online and hybrid Exchange
- SharePoint, OneDrive, Teams, Groups and public folders
- Device, Intune, Autopilot and application migration
- Coexistence, pilot waves, pre-stage, delta sync and cutover
- Throttling, retry, errors, reconciliation and validation
- Communications, training, hypercare, rollback and decommissioning

## Migration tools

- Microsoft-native migration tools and Migration Manager
- BitTitan MigrationWiz
- Quest On Demand Migration
- ShareGate
- Cloudiway
- AvePoint
- Xillio
- Tool selection, licensing, limitations, security, reporting and escalation

## Security operations

- Defender for Cloud, Defender for Identity, Defender for Endpoint
- Defender for Cloud Apps, Purview and security posture
- Log Analytics, Sentinel, KQL, workbooks, analytics rules and automation
- Identity and NHI detections, threat hunting and attack-path analysis
- Vulnerability management, secure score and remediation tracking
- Incident response, containment, eradication, recovery and RCA
- Audit evidence, SOC 2, ISO 27001, NIST, CIS, PCI, HIPAA, GDPR and DPDPA mapping

## Secure AI

- AI fundamentals, Azure AI and Azure OpenAI
- AI Search, RAG, embeddings, data ingestion and access control
- Agent identity, tools, permissions and excessive agency
- Private networking, Key Vault, data classification and retention
- Prompt injection, data leakage, poisoning, insecure output and supply chain
- Evaluation, logging, tracing, human approval, safety and governance

## Operations and reliability

- Azure Monitor, Application Insights, alerts and action groups
- Logs, metrics, traces, dashboards and service health
- SLI, SLO, SLA, error budgets and capacity planning
- Performance, autoscaling, quotas and throttling
- Backup, restore, RTO, RPO, DR and restore testing
- Incident command, severity, communications and post-incident review
- Runbooks, SOPs, operational acceptance and service handover
- Chaos/failure injection and preventive controls

## Customer delivery

- Discovery workshop and requirements traceability
- Current-state assessment and target-state architecture
- HLD, LLD, ADR, risk register and assumptions
- Configuration checklist and implementation plan
- Pilot plan, test plan, acceptance criteria and change plan
- Migration/cutover/rollback plan and communications
- Operations manual, SOP, training and handover
- Executive status report and post-implementation review

## Industry cases

- Banking and fintech
- Healthcare
- Retail and e-commerce
- SaaS and technology
- Manufacturing and OT
- Government and public sector
- Education
- Nonprofit
- Mergers, acquisitions and divestitures

## Evidence requirement

The register is not a claim that each item is complete. It is the gap-control mechanism. Every item must eventually link to a topic, lab, break/fix, customer case, and evidence artifact.

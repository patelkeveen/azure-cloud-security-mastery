# Curriculum Map

## Depth model

Every topic is learned at three levels and across seven dimensions.

### Fundamentals

Definition, purpose, terminology, architecture, dependencies, boundaries, basic commands, basic lab, misconceptions.

### Intermediate

Integration with identity/networking/data, automation using CLI/PowerShell/Bicep/Terraform, monitoring, three failure scenarios, security controls, cost, availability, and recovery.

### Mastery and customer expertise

Architecture alternatives, threat model, migration or recovery, multiple industries, audit evidence, operational handover, customer objection handling, capacity and cost, rollback, and teaching.

### Seven dimensions

Fundamentals, implementation, integration, operations, security, architecture, and customer delivery.

## Domains and subdomains

### 00 Foundations

Hardware, OS, processes, filesystems, permissions, Linux, Windows, CLI, PowerShell, Python basics, Git, APIs, JSON, authentication, virtualization, containers, troubleshooting and documentation.

### 10 Networking

OSI/TCP-IP, IPv4/IPv6, CIDR/subnetting, ARP, ICMP, TCP/UDP, HTTP/S, DNS, DHCP, NAT, routing, BGP awareness, firewalls, TLS, certificates, proxies, load balancing, VNet, NSG, UDR, peering, hub-spoke, VPN, ExpressRoute, private endpoints, private DNS, Azure Firewall, Front Door and Application Gateway.

### 20 Azure platform

Subscriptions, management groups, resource groups, ARM, tags, locks, RBAC, Azure Policy, budgets, quotas, Azure Advisor, Bicep, Terraform, landing zones, Azure Resource Graph, cost allocation, governance exceptions, and deployment strategies.

### 30 Identity and NHI

Users, groups, administrative units, authentication, Conditional Access, Identity Protection, passwordless, PIM, access reviews, entitlement management, lifecycle workflows, external identities, app registrations, enterprise applications, service principals, managed identities, workload federation, Key Vault, certificates, secrets rotation, OAuth/OIDC/SAML, SCIM, consent, ownership, NHI inventory, and NHI incident response.

### 35 AD and hybrid identity

AD DS, domains, forests, trusts, DNS dependency, Kerberos, LDAP, Group Policy, AD Connect Sync, Cloud Sync, PHS, PTA, federation, ADFS, source anchor, immutable ID, soft/hard match, Connect Health, staging mode, certificate dependencies, coexistence, domain changes, tenant consolidation, and rollback.

### 40 Microsoft 365 platform

Exchange Online, Exchange Server, hybrid Exchange, mail flow, connectors, transport rules, relay, SMTP, SPF, DKIM, DMARC, mail hygiene, Autodiscover, OAuth, public folders, SharePoint Online, OneDrive, Teams, Microsoft 365 Groups, permissions, external sharing, retention, sensitivity, DLP, Viva awareness, Power Platform governance, licensing, limits, throttling, service health, and tenant architecture.

### 45 M365 migration engineering

Discovery, assessment, inventory, data classification, dependency mapping, identity remediation, licensing, pilot design, coexistence, pre-stage, delta sync, migration waves, cutover, rollback, user communication, throttling, retry, validation, reconciliation, support hypercare, decommissioning, and post-migration review.

Migration factories: Google Workspace to M365; tenant-to-tenant; Exchange hybrid; SharePoint/OneDrive; Teams; public folders; identity and device migration.

Tool ecosystem: Microsoft native, BitTitan MigrationWiz, Quest On Demand, ShareGate, Cloudiway, AvePoint, Xillio, and tool-selection criteria. Each tool receives research, trial/sandbox, limitation, evidence, and verified-status labels.

### 50 Security operations

Defender for Cloud, Defender for Identity, Defender for Endpoint, Defender for Cloud Apps, Sentinel, Log Analytics, KQL, cloud posture, attack paths, vulnerability management, threat hunting, identity detections, NHI detections, Purview, incident response, containment, RCA, and audit evidence.

### 60 AI and secure AI

AI fundamentals, Azure AI, Azure OpenAI, RAG, AI Search, agents, private networking, Key Vault, NHI, prompt injection, data leakage, data poisoning, excessive agency, model access, evaluation, logging, human approval, safety, privacy, and governance.

### 70 Operations and reliability

Azure Monitor, Application Insights, alerts, SLI/SLO/SLA, capacity, performance, change management, incident command, runbooks, backup, restore, RTO, RPO, DR tests, chaos exercises, service review, and handover.

### 75 Architecture and consulting

Discovery workshop, requirements, assumptions, constraints, current-state assessment, target architecture, HLD, LLD, ADR, risk register, configuration checklist, implementation plan, test plan, migration runbook, change window, rollback, SOP, operations manual, training, handover, and executive readout.

## Certification mapping

| Certification | Baseline | Beyond-exam requirement |
|---|---|---|
| AZ-104 | Azure administration, identity/governance, storage, compute, networking, monitoring | IaC, landing zones, migration, reliability, DR, cost, operations |
| AZ-500 | Azure security across platform, network, compute, data, identity | Threat modeling, attack paths, detection, response, evidence |
| SC-300 | Workforce identity, authentication, workload identity, governance | Hybrid migration, tenant consolidation, NHI lifecycle, customer implementation |
| SC-500 / Cloud and AI Security | Cloud and AI security | AI threat modeling, agent identity, data boundaries, evaluation, response |
| AI | AI services and workloads | Secure RAG, private access, NHI, governance, testing, evaluation |
| Networking | Core network and Azure connectivity | Packet troubleshooting, hybrid design, segmentation, resilience |

## Required customer deliverables

Discovery questionnaire, current-state assessment, inventory, dependency map, HLD, LLD, ADR, risk register, configuration checklist, pilot plan, test plan, migration/cutover plan, rollback plan, communication plan, validation report, operations manual, SOP, training guide, handover and post-implementation review.

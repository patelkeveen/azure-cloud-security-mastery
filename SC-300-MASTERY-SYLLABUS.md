# SC-300 Mastery Syllabus — Custom Deep-Dive Map

> **Purpose:** not exam-passing. Job capability. This maps every SC-300 objective to the
> underlying concepts you must own to walk into any customer, in any vertical, and design,
> implement, troubleshoot, and defend a Microsoft Entra identity estate.
>
> **Built:** 2026-08-08
> **Authoritative sources:** SC-300 skills measured as of **2026-04-27**; AZ-104 as of
> 2026-04-17; AZ-500 as of 2026-01-22 (**retires 2026-08-31**); SC-500 (successor).
> **Legacy source:** "SC-300 Custom TOC" PDF (Feb 2025, third-party) — superseded by this doc.

---

## 0. How to read this map

Four columns, matching the industry-standard training taxonomy:

**MS Cloud Service → Domain → Sub-Domain → Training Topic**

Every topic carries a scope tag:

| Tag | Meaning | How to study it |
|---|---|---|
| `[CORE]` | Explicitly on SC-300 (2026-04-27) | Must be able to *do* it in a tenant, from portal + Graph PowerShell |
| `[PREREQ]` | Not tested on SC-300, but SC-300 is unlearnable without it | Understand mechanism; don't need admin-level fluency |
| `[SHALLOW]` | On SC-300 as one bullet, but weeks deep in real work | **Highest ROI. This is where consultants are made.** |
| `[BEYOND]` | Not on SC-300; required for the job and/or SC-500 | Learn after core is solid |
| `[DEAD]` | Retired — recognise the name, don't implement | Read once, move on |

### Exam weightings (SC-300, effective 2026-04-27)

| Domain | Weight |
|---|---|
| D1 — Implement and manage user identities | 20–25% |
| D2 — Implement authentication and access management | 25–30% |
| D3 — Plan and implement workload identities | 20–25% |
| D4 — Plan and automate identity governance | 20–25% |

> *Note: Microsoft's own page lists D2 as 25–30% in "Skills at a glance" and 20–25% in the
> section heading. Treat D2 as the largest domain and study accordingly.*

---

## LAYER 0 — Prerequisite Substrate `[PREREQ]`

The things SC-300's audience profile assumes you already know. Every one of these is a
real-world failure mode. Skipping this layer is why people pass SC-300 and still can't fix
a broken hybrid tenant.

| Sub-Domain | Training Topic | Why it bites you on the job |
|---|---|---|
| **DNS** | Record types (A, CNAME, MX, TXT, SRV), TTL and propagation, split-horizon DNS, conditional forwarders | Custom domain verification, federation endpoints, Seamless SSO, and Connect Sync **all** fail as DNS problems first |
| **PKI & certificates** | X.509 chain of trust, CA hierarchy, CRL/OCSP, SAN vs CN, cert lifecycle and rotation | Certificate-Based Auth, SAML token-signing cert rollover, AD FS cert expiry — the classic 3am outage |
| **TLS** | Handshake, cipher suites, TLS 1.2 vs 1.3, mutual TLS | Legacy client breakage when TLS floors are raised |
| **HTTP** | Methods, status codes, headers, redirects (302 vs 307), CORS, cookies (`SameSite`, `Secure`, `HttpOnly`) | Every SSO flow is a redirect chain. You will read HAR files. |
| **AD DS** | Forest/domain/OU, FSMO roles, sites & services, replication, GPO, LDAP, **Kerberos (TGT, TGS, SPN, delegation)**, NTLM | Hybrid identity is AD DS projected into the cloud. Kerberos ignorance = cannot debug Entra Kerberos / cloud Kerberos trust |
| **Networking** | IPv4 subnetting/CIDR, NAT, routing, firewalls, proxies, TCP vs UDP | Named locations, trusted IPs, Global Secure Access, Application Proxy connector placement |
| **Azure platform** | Management groups → subscriptions → resource groups → resources; ARM; Azure Policy; resource locks; tags | Azure RBAC scope inheritance and PIM for Azure resources are meaningless without this hierarchy |
| **Identity theory** | AuthN vs AuthZ, IdP vs SP vs RP, claims, federation, **Zero Trust** (verify explicitly, least privilege, assume breach) | The vocabulary of every customer conversation |
| **Cryptography** | Symmetric vs asymmetric, hashing vs encryption, digital signatures, nonce, salt | Why PHS stores a hash-of-a-hash; why a JWT signature matters |
| **PowerShell** | Objects/pipeline, `Where-Object`/`Select-Object`, splatting, error handling, modules | Bulk ops, reporting, remediation |
| **KQL** | `where`/`project`/`summarize`/`join`/`bin`, time ranges, `parse_json`, `mv-expand` | Sign-in log forensics. Named in the audience profile; barely tested; used daily |
| **REST & JSON** | Verbs, status codes, pagination (`@odata.nextLink`), throttling (429 + `Retry-After`) | Microsoft Graph is a REST API. All automation runs through it. |

> **Mapped from your legacy TOC:** the *Cloud Computing Fundamentals*, *Azure Networking
> Services*, *Azure Storage Services*, and *Compute Fundamentals* sections (~100 bullets)
> collapse into this layer. They are **prerequisite substrate, not SC-300 content**. Learn the
> mechanism (what a VNet/NSG/storage account *is* and how identity attaches to it); do not
> grind AZ-104 storage-tier trivia.

---

## LAYER 1 — Identity Protocols `[SHALLOW]` ⭐ HIGHEST ROI

**This layer does not appear as a section in any Microsoft study guide, and it is the single
biggest separator between "certified" and "senior."** SC-300 tests *outcomes* ("configure app
authentication"). The job tests *mechanism* ("why does this token lack the `groups` claim?").

| Sub-Domain | Training Topic | Depth required |
|---|---|---|
| **OAuth 2.0** | Roles (resource owner, client, auth server, resource server); **Authorization Code + PKCE**, Client Credentials, Device Code, On-Behalf-Of; ROPC (deprecated — know why); implicit flow (dead — know why) | Must be able to pick the correct flow for a given app topology and defend the choice |
| **OpenID Connect** | ID token vs access token; `/.well-known/openid-configuration`; scopes vs claims; `nonce`; hybrid flow | Must be able to read a discovery document |
| **JWT internals** | Header/payload/signature; `iss`, `aud`, `sub`, `oid`, `tid`, `exp`, `nbf`, `iat`, `amr`, `acr`, `scp`, `roles`, `wids`, `groups`; signature validation; `kid` and key rollover | **Must be able to decode a token by hand and explain every claim.** This is the #1 troubleshooting skill |
| **Token lifetimes** | Access token (default ~60–90 min, variable), refresh token, primary refresh token (PRT), **Continuous Access Evaluation** and claims challenges, token revocation vs expiry | Explains "I disabled the account, why is he still in?" |
| **SAML 2.0** | Assertion structure, SP-init vs IdP-init, `NameID` formats, signing vs encryption, metadata XML, `RelayState` | Every legacy SaaS integration |
| **WS-Federation** | Where it survives, why it's legacy | Older on-prem apps |
| **SCIM 2.0** | Schema, `/Users` `/Groups`, PATCH semantics, attribute mapping and expressions | Automated provisioning to SaaS |
| **Consent framework** | Delegated vs application permissions; user vs admin consent; `/.default`; admin consent workflow; **illicit consent grant attack** | Security-critical and heavily under-taught |
| **Graph API** | Permission model, `v1.0` vs `beta`, throttling, batching, `$select`/`$filter`/`$expand`, change notifications | Everything automated goes through here |

**Lab gate for this layer:** capture a real sign-in with browser devtools, extract the JWT,
decode it, and narrate every claim. Then explain why a CA policy fired.

---

## LAYER 2 — SC-300 DOMAIN 1: Implement and Manage User Identities (20–25%)

### 1.1 Configure and manage a Microsoft Entra tenant

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Configure and manage built-in and custom Entra roles | `[CORE]` | Role definition JSON; `microsoft.directory/*` action strings; **role assignability to groups**; why custom roles need P1 |
| Recommend when to use administrative units | `[CORE]` | The decision framework: AU vs separate tenant vs RBAC scoping — what you'd tell a customer |
| Configure and manage administrative units | `[CORE]` | **Restricted Management AUs** `[BEYOND]` — protects objects even from Global Admin; dynamic-membership AUs |
| Evaluate effective permissions for Entra roles | `[CORE]` | Role assignment inheritance, PIM-eligible vs active, scoping to AU vs directory |
| Configure and manage domains in Entra ID and M365 | `[CORE]` | TXT/MX verification mechanics; federated vs managed domain; **domain takeover risk** |
| Configure Company branding | `[CORE]` | Per-language branding; CIAM branding differences |
| Configure tenant/user/group/device settings | `[CORE]` | `Users can register applications` and its blast radius; guest inviter restrictions; LAPS |

### 1.2 Create, configure, and manage Entra identities

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Create, configure, and manage users | `[CORE]` | Cloud-only vs synced vs guest; `onPremisesImmutableId`; UPN vs mail vs proxyAddresses; soft-delete 30-day window |
| Create, configure, and manage groups | `[CORE]` | Security vs M365 group; **dynamic membership rule syntax** and evaluation latency; group nesting limits in licensing; group writeback |
| Manage custom security attributes | `[CORE]` | Attribute sets, the separate RBAC model (Attribute Definition Administrator), use in ABAC |
| Automate bulk operations (admin center + PowerShell) | `[CORE]`→`[SHALLOW]` | **Microsoft Graph PowerShell SDK.** `MSOnline`/`AzureAD` modules are retired — know the migration map. Batching, throttling, `-ErrorAction` patterns, idempotent scripts |
| Manage device join and registration | `[CORE]` | **Entra joined vs Entra registered vs Hybrid joined** — the decision tree; PRT issuance; Windows Hello for Business dependency; Intune enrolment interplay `[BEYOND]` |
| Assign, modify, report on licenses | `[CORE]` | Group-based licensing; conflict resolution; `Set-MgUserLicense`; service plan disablement |

### 1.3 External identities

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| External collaboration settings | `[CORE]` | Guest permission levels; domain allow/deny lists |
| Invite external users individually/bulk | `[CORE]` | Redemption flow; email OTP fallback; `#EXT#` UPN mangling |
| Manage external user accounts | `[CORE]` | Guest lifecycle; conversion to member |
| **Cross-tenant access settings** | `[CORE]` | Inbound/outbound B2B collab vs B2B direct connect; **trust MFA/compliant device from home tenant** — the M&A workhorse |
| Cross-tenant synchronization | `[CORE]` | Multi-tenant org; sync scoping/attribute mapping; vs Connect Sync |
| External identity providers (SAML/WS-Fed, Google, Facebook) | `[CORE]` | Federation for guests; direct federation limits |
| **Microsoft Entra External ID (CIAM)** | `[BEYOND]` | Successor to Azure AD B2C (closed to new tenants). Customer-facing identity: user flows, custom branding, social IdPs. **Any B2C customer engagement needs this** |

### 1.4 Hybrid identity `[SHALLOW]` ⭐

> One study-guide bullet each. Weeks of real depth. Most consulting revenue lives here.

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Entra Connect Sync | `[CORE]`→`[SHALLOW]` | Connector space ↔ metaverse ↔ cloud; **sync rules editor**; precedence; inbound/outbound rules; filtering (OU/attribute); **source anchor / `ms-DS-ConsistencyGuid`**; soft match vs hard match; duplicate attribute resiliency; staging mode; `Start-ADSyncSyncCycle -PolicyType Delta\|Initial`; sync errors and how to read them; upgrade/swing migration |
| Entra Cloud Sync | `[CORE]` | Agent-based, no server; **when to choose Cloud Sync over Connect Sync** (multi-forest, M&A, disconnected forests); feature gaps (no device writeback, no pass-through of some attrs) |
| Password hash synchronization | `[CORE]` | The hash-of-the-hash mechanism (why it isn't "sending passwords to the cloud") — you *will* have to defend this to a security team; **leaked-credential detection depends on PHS** |
| Pass-through authentication | `[CORE]` | Agent architecture, outbound-only, HA with ≥3 agents, failure modes |
| Seamless SSO | `[CORE]` | The `AZUREADSSOACC` computer object, Kerberos ticket to `autologon.microsoftazuread-sso.com`, **rolling the AZUREADSSOACC password every 30 days** |
| Migrate from AD FS | `[CORE]` | Federated → managed cutover; staged rollout; `Set-MsolDomainAuthentication` successor cmdlets; rollback plan; **what breaks** (claims rules, MFA adapters) |
| Entra Connect Health | `[CORE]` | Agent monitoring, sync error reporting, AD FS/AD DS health |
| Hybrid join | `[BEYOND]` | SCP configuration, device registration via GPO, downlevel OS |

---

## LAYER 3 — SC-300 DOMAIN 2: Authentication & Access Management (25–30%)

### 2.1 User authentication

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Plan for authentication | `[CORE]` | Authentication method **strength** ranking; migration off SMS; the Authentication Methods policy (replacing legacy MFA/SSPR policies) |
| Auth methods: CBA, TAP, OAuth tokens, Authenticator, **passkeys (FIDO2)** | `[CORE]` | **Terminology updated 2026** — "passkeys (FIDO2)" now, incl. device-bound passkeys in Authenticator. CBA: username binding, PKI trust store, affinity levels. TAP: onboarding + break-glass use |
| Tenant-wide MFA settings | `[CORE]` | Migrating off legacy per-user MFA; Microsoft-managed policies; number matching |
| SSPR | `[CORE]` | Registration policy, writeback dependency for hybrid, combined registration |
| **Windows Hello for Business** | `[CORE]` | Cloud Kerberos trust vs key trust vs cert trust — **the decision tree**; deployment prerequisites |
| Disable accounts and revoke sessions | `[CORE]` | `Revoke-MgUserSignInSession`; refresh-token invalidation vs access-token TTL; **why revocation isn't instant without CAE** |
| Entra password protection | `[CORE]` | Global + custom banned lists, fuzzy matching, on-prem DC agent + proxy, audit vs enforce |
| Entra Kerberos for hybrid | `[CORE]` | Cloud Kerberos trust; Azure Files with Entra Kerberos |

### 2.2 Conditional Access `[SHALLOW]` ⭐⭐ — the centre of gravity

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Plan CA policies | `[CORE]` | **Policy evaluation logic: ALL policies evaluate; grant controls within a policy are OR unless "require all"; block always wins.** Persona-based design; naming conventions; the Microsoft-recommended baseline set |
| Policy assignments | `[CORE]` | Users/groups/roles/guests; **exclusion strategy**; break-glass exclusion (mandatory); workload identities as targets |
| Policy controls | `[CORE]` | Grant vs Session; require MFA / compliant device / Hybrid joined / approved app / app protection policy; **authentication strength** (replaces "require MFA" granularity) |
| Test and troubleshoot | `[CORE]`→`[SHALLOW]` | **What-If tool**; **report-only mode**; reading the CA tab of a sign-in log; "policy not applied" reason codes. This is the daily job |
| Session management | `[CORE]` | Sign-in frequency, persistent browser, **token protection / sign-in session token binding** `[BEYOND]`, CAE strict enforcement |
| Device-enforced restrictions | `[CORE]` | Requires Intune compliance — the Intune dependency `[BEYOND]` |
| Continuous access evaluation | `[CORE]` | Critical event vs policy evaluation; claims challenge; which apps support it; the ~5-min-to-near-real-time revocation story |
| Authentication context | `[CORE]` | `c1`–`c25` values; binding to sensitivity labels, PIM activation, and protected actions |
| Protected actions | `[CORE]` | Binding auth context to high-risk directory permissions (e.g. deleting CA policies) |
| Policy from template | `[CORE]` | Template catalogue; when templates are wrong for the customer |
| **Filter for devices** | `[BEYOND]` | Rule-based device targeting — heavily used in practice |

### 2.3 Entra ID Protection

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| User risk policy | `[CORE]` | Risk levels; **leaked credentials requires PHS**; remediation vs dismissal |
| Sign-in risk policy | `[CORE]` | Real-time vs offline detections; anonymous IP, impossible travel, unfamiliar sign-in, token anomaly |
| MFA registration via **registration campaigns** | `[CORE]` | *Updated 2026-04-27 wording* — nudge users from SMS to Authenticator |
| Investigate/remediate risky users & sign-ins | `[CORE]` | Risky users report, confirm-compromised/safe feedback loop (it trains the model) |
| **Risky workload identities** | `[CORE]` | Service principal risk detections — under-taught, increasingly exploited |

### 2.4 Global Secure Access

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Deploy GSA clients | `[CORE]` | Platform support; traffic forwarding profiles |
| Private Access | `[CORE]` | **Successor to Application Proxy for TCP/UDP**; Quick Access vs per-app; connector groups; ZTNA positioning vs legacy VPN |
| Internet Access | `[CORE]` | SWG capability; web content filtering; compliant network check in CA |
| Internet Access for M365 | `[CORE]` | M365 traffic profile; tenant restrictions v2 |

---

## LAYER 4 — SC-300 DOMAIN 3: Workload Identities (20–25%)

> **Strategic note:** this domain is the bridge to SC-500 and to "Security AI Infra Engineer."
> Non-human identity now outnumbers human identity in most tenants and is the dominant breach path.

### 3.1 Identities for applications and Azure workloads

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Select appropriate identity type | `[CORE]` | **Decision tree:** system-assigned MI vs user-assigned MI vs SP with secret vs SP with cert vs **workload identity federation**. Defend the choice |
| Create managed identities | `[CORE]` | System vs user-assigned lifecycle; the implicit SP created in Entra |
| Assign MI to an Azure resource | `[CORE]` | Which resource types support it; IMDS endpoint mechanics |
| Use MI to access other resources | `[CORE]` | `DefaultAzureCredential` chain; RBAC on the target; token acquisition from `169.254.169.254` |
| **Workload identity federation** | `[BEYOND]` ⭐ | **Secretless CI/CD.** GitHub Actions OIDC → Entra; Kubernetes service accounts → Entra; issuer/subject/audience matching. Eliminates the #1 leaked-secret vector. Not on SC-300; asked in every senior interview |
| **Entra Agent ID** | `[BEYOND]` ⭐ | Identity for AI agents. **On SC-500.** CA for Agent ID, blast-radius analysis in Defender XDR, agent access management |

### 3.2 Enterprise applications

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| App-level and tenant-level settings | `[CORE]` | Assignment required, visibility, self-service access |
| Entra roles for managing enterprise apps | `[CORE]` | Cloud App Admin vs App Admin vs app owner — least privilege |
| **Application Proxy** for on-prem apps | `[CORE]` | Connector architecture, pre-auth modes, KCD for backend Kerberos, header-based auth; **vs Private Access** (know when to recommend each) |
| SaaS app integration | `[CORE]` | Gallery vs non-gallery; SAML config; claims mapping policy; **SCIM provisioning** and attribute expressions |
| Users/groups/app roles assignment | `[CORE]` | App role definition, assignment to groups/SPs |
| User and admin consent | `[CORE]` | Consent policies; admin consent workflow; **illicit consent grant attack + detection** |
| Application collections | `[CORE]` | MyApps portal organisation |

### 3.3 App registrations

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Plan for app registrations | `[CORE]` | Single vs multi-tenant; app object vs SP object (**the distinction people get wrong**) |
| Create app registrations | `[CORE]` | Redirect URIs, platform configs |
| Configure app authentication | `[CORE]` | Secrets vs certificates vs federated credentials; **secret expiry monitoring** |
| Configure API permissions | `[CORE]` | Delegated vs application; `/.default`; least-privilege Graph scopes |
| Create app roles | `[CORE]` | RBAC inside your own app; `roles` claim |
| **Token configuration / claims mapping** | `[BEYOND]` | Optional claims, group claim overage (>150/200 groups → `_claim_names`) — a classic production bug |

### 3.4 Defender for Cloud Apps

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Cloud discovery | `[CORE]` | Log collector, shadow IT discovery, risk scoring |
| Connected apps | `[CORE]` | API connectors per SaaS |
| App-enforced restrictions | `[CORE]` | Limited web session in M365 |
| **Conditional Access App Control** | `[CORE]` | Reverse proxy session control — the CA ↔ MDA handoff |
| Access and session policies | `[CORE]` | Inline DLP, download blocking, real-time controls |
| OAuth app policies | `[CORE]` | Detecting malicious OAuth grants — pairs with illicit consent above |
| Cloud app catalog | `[CORE]` | Risk scoring methodology, custom scores |

---

## LAYER 5 — SC-300 DOMAIN 4: Identity Governance (20–25%)

### 4.1 Entitlement management

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Plan entitlements | `[CORE]` | Requires **Entra ID Governance** licence — surface this early in customer scoping |
| Catalogs | `[CORE]` | Catalog owners, delegation model |
| Access packages | `[CORE]` | Resource roles, policies, multi-stage approval, expiry, separation of duties |
| Manage access requests | `[CORE]` | Approver experience, auto-assignment policies |
| Terms of use | `[CORE]` | Per-language, CA integration, audit trail |
| Lifecycle of external users | `[CORE]` | Guest expiry and auto-removal via access packages |
| Connected organizations | `[CORE]` | Partner tenant onboarding at scale |

### 4.2 Access reviews

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Plan for access reviews | `[CORE]` | Scope selection; **who is the right reviewer** (manager vs owner vs self) |
| Create and configure | `[CORE]` | Recurrence, auto-apply, "if reviewers don't respond" behaviour |
| Monitor activity | `[CORE]` | Completion reporting; audit evidence for SOC 2 / ISO 27001 |
| Respond manually | `[CORE]` | Bulk decisions, recommendations based on sign-in activity |

### 4.3 Privileged access

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| PIM for Entra roles | `[CORE]` | Eligible vs active; activation max duration; MFA/justification/approval on activation; **auth context binding** |
| PIM for Azure resources | `[CORE]` | Scope at MG/sub/RG/resource; requires the Azure hierarchy from Layer 0 |
| **PIM for Groups** | `[CORE]` | *Renamed 2026-04-27* (was "groups managed by PIM"). Just-in-time group membership — the workaround for services without native PIM |
| Request and approval process | `[CORE]` | Approver assignment, notification flow |
| PIM audit history and reports | `[CORE]` | Activation history for evidence |
| **Break-glass accounts** | `[CORE]` ⭐ | **Design pattern:** ≥2 accounts, cloud-only, `.onmicrosoft.com`, excluded from ALL CA policies, no MFA dependency on a single method, credentials split and physically secured, sign-in alerting. **Every customer asks. Many get it wrong.** |

### 4.4 Monitoring

| Training Topic | Scope | Deep-dive extension |
|---|---|---|
| Sign-in, audit, provisioning logs | `[CORE]` | Log schema; interactive vs non-interactive vs SP vs MI sign-ins (**four separate tabs — people miss three**); 30-day default retention |
| Diagnostic settings → LAW / storage / Event Hub | `[CORE]` | Retention beyond 30 days; cost modelling; Event Hub → third-party SIEM |
| **KQL over Entra logs** | `[CORE]`→`[SHALLOW]` ⭐ | `SigninLogs`, `AuditLogs`, `AADNonInteractiveUserSignInLogs`, `AADServicePrincipalSignInLogs`, `RiskyUsers`, `IdentityInfo`. Build a personal query library |
| Workbooks and reporting | `[CORE]` | Built-in workbooks: Sign-ins, CA gap analysis, Sensitive Operations |
| Identity Secure Score | `[CORE]` | Scoring model; using it as a customer-facing roadmap artifact |
| ~~Entra Permissions Management / PCI~~ | `[DEAD]` | **Retired 2026-11-01**, auto-offboarded. CIEM moved to **Defender CSPM**. Present in older TOCs — do not implement |

---

## LAYER 6 — Beyond SC-300: the SC-500 bridge `[BEYOND]`

> AZ-500 retires **2026-08-31**. Successor: **SC-500 — Implementing End-to-End Security Controls
> for Cloud and AI Workloads** (*Cloud and AI Security Engineer Associate*). This is the
> "Security AI Infrastructure Engineer" role, certified.

| Sub-Domain | Training Topic | Relationship to SC-300 |
|---|---|---|
| **AI security** | Entra **Agent ID**; Conditional Access for Agent ID; blast-radius analysis in Defender XDR; managing agent access | Direct extension of D3 workload identities |
| | Defender for AI Services; AI Gateway in **Azure API Management** for Microsoft Foundry; guardrails for Foundry agents | New surface |
| | Purview **DSPM for AI**; Copilot/agent data-exposure risk; SharePoint overexposure | New surface |
| | Copilot Studio agent real-time protection; agent management in M365 admin center | New surface |
| **Key Vault** | Deploy/configure; access model (RBAC vs access policy); firewall; key/secret/cert management; rotation; Defender for Key Vault; secret scanning via Defender CSPM | Where app credentials live — completes D3 |
| **Governance** | Azure Policy (built-in + custom); regulatory compliance in Defender for Cloud; resource locks; **overprivileged RBAC remediation**; IaC security controls | Extends D4 into the resource plane |
| **Sentinel** | Workspaces, roles, content hub, data connectors, DCRs, syslog/CEF, WEF, custom tables, automation rules and playbooks, retention | Where D4's diagnostic settings terminate |
| **Security Copilot** | Workspaces, permissions, plugins, agents | New tier |
| **Network security** | NSG/ASG, Virtual Network Manager, Azure Firewall, private endpoints/Private Link, **Entra Private Access** | Private Access overlaps SC-300 D2 directly |

---

## LAYER 7 — Industry vertical use cases

> Same product, different constraint. This is what makes you portable across customers.
> For each: the driver, the identity design, and the trap.

### Financial services / banking
- **Drivers:** SOX, PCI-DSS, FFIEC; segregation of duties; auditable privileged access
- **Design:** PIM mandatory for all privileged roles with approval + justification; access
  reviews quarterly with auto-apply; CA requiring compliant device + phishing-resistant
  authentication strength for admin roles; auth context + protected actions on directory changes
- **Trap:** SoD is an *entitlement* problem, not a role problem — enforce via access package
  separation-of-duties, not custom roles

### Healthcare
- **Drivers:** HIPAA/PHIPA; shared clinical workstations; break-glass to patient data
- **Design:** shared-device mode; short sign-in frequency; FIDO2/passkeys over SMS (gloves,
  sterile fields); Entitlement Management for rotating residents and locums
- **Trap:** clinicians will defeat any auth method that costs >5 seconds at the bedside; test
  with real workflow before rollout

### Government / public sector
- **Drivers:** FedRAMP/IRAP/ITSG-33; sovereignty; CBA via PIV/CAC
- **Design:** Certificate-Based Authentication with PKI trust store; sovereign cloud boundaries;
  no consumer social IdPs; strict tenant restrictions
- **Trap:** sovereign clouds have feature-parity gaps — verify every feature is available in the
  target cloud before designing

### Manufacturing / OT
- **Drivers:** shop-floor shared accounts; air-gapped or intermittently connected networks; legacy HMI
- **Design:** Application Proxy or Private Access for legacy line-of-business apps; device-bound
  passkeys for shared terminals; named locations for plant networks
- **Trap:** OT systems often can't do modern auth at all — the honest answer is a segmented
  network plus a jump path, not "make it SSO"

### Retail
- **Drivers:** high-churn seasonal workforce; POS terminals; franchise multi-tenancy
- **Design:** Lifecycle Workflows for joiner/mover/leaver at scale; entitlement management for
  seasonal onboarding; cross-tenant access for franchisees
- **Trap:** deprovisioning latency at scale — measure the leaver path end-to-end

### SaaS / technology
- **Drivers:** engineer velocity vs least privilege; heavy CI/CD; multi-cloud
- **Design:** **workload identity federation** (GitHub Actions/K8s → Entra, no secrets); PIM for
  production access; SCIM to every SaaS; risky workload identity monitoring
- **Trap:** long-lived SP secrets in pipelines — the most common real breach path

### Education
- **Drivers:** enormous student populations, annual cohort churn, BYOD, minors
- **Design:** dynamic groups by enrolment attribute; SSPR at scale; guest access for
  parents/alumni; External ID for applicant portals
- **Trap:** licensing model differs (A1/A3/A5) — governance features may simply not be licensed

### Mergers & acquisitions ⭐
- **Drivers:** two tenants, one company, day-one collaboration
- **Design:** **cross-tenant access settings** (trust MFA/compliant device from the other tenant),
  **cross-tenant synchronization**, multi-tenant organization; then Cloud Sync for the AD forests;
  long-run tenant consolidation
- **Trap:** UPN collisions and duplicate `ms-DS-ConsistencyGuid` values — plan the matching
  strategy before syncing anything

### Nonprofit
- **Drivers:** minimal budget, volunteer identity, donated licensing
- **Design:** maximise free/P1 tier; Security Defaults where CA isn't licensed; guest-heavy model
- **Trap:** designing for P2 features the customer will never afford

---

## Appendix A — Legacy TOC reconciliation

| Legacy TOC section | Disposition |
|---|---|
| Cloud Computing Fundamentals (27 items) | → **Layer 0**, compressed. Concept only |
| Azure Networking Services (21) | → **Layer 0** + Layer 6 network security |
| Azure Storage Services (21) | → **Layer 0**, minimal. Only identity-to-storage auth matters |
| Compute Fundamentals (33) | → **Layer 0** + Layer 6 (`[BEYOND]`) |
| Identity & Access Management (~140) | → **Layers 2–5**. Core content, re-sequenced and updated |
| Governance & Monitoring (~50) | → **Layer 5** + Layer 6 |

**Corrections applied to the legacy source (Feb 2025 → Aug 2026):**
1. "Azure AD" → **Microsoft Entra ID** throughout
2. "FIDO2" → **passkeys (FIDO2)** — 2026-04-27 objective wording
3. "groups managed by PIM" → **PIM for Groups**
4. "MFA registration policies" → **registration campaigns**
5. **Entra Permissions Management + Permissions Creep Index — REMOVED** (retired 2026-11-01)
6. Azure AD B2C → **Entra External ID** (B2C closed to new tenants)
7. **Added:** authentication strengths, token protection, restricted management AUs,
   workload identity federation, Entra Agent ID, Verified ID, Global Secure Access detail
8. Logic Apps deep dive → demoted; retained only for **Lifecycle Workflows custom task extensions**

## Appendix B — Repo mapping

This syllabus overlays the existing folder taxonomy:

| Syllabus layer | Repo path |
|---|---|
| Layer 0 | `00-foundations/`, `10-networking/`, `20-azure-platform/` |
| Layer 1 (protocols) | `30-identity-and-nhi/oauth-oidc-saml-and-api-auth/` |
| Layer 2 (D1) | `30-identity-and-nhi/entra-users-and-groups/`, `external-identities/`, `hybrid-identity/`, `35-active-directory-and-hybrid-identity/` |
| Layer 3 (D2) | `30-identity-and-nhi/authentication-methods/`, `conditional-access/`, `identity-protection/`, `passwordless-and-passkeys/` |
| Layer 4 (D3) | `30-identity-and-nhi/managed-identities/`, `service-principals/`, `app-registrations/`, `workload-identity-federation/` |
| Layer 5 (D4) | `30-identity-and-nhi/pim-and-access-reviews/`, `entitlement-management/`, `lifecycle-workflows/` |
| Layer 6 | `50-security-operations/`, `60-ai-and-secure-ai/` |
| Layer 7 | `80-customer-scenarios/` |

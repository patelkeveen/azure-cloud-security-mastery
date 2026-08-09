# SC-300 Resource Library — what a staff engineer actually reads

> Companion to `SC-300-MASTERY-SYLLABUS.md`. That doc says *what* to learn; this says *where*.
> Built 2026-08-09. Complements the existing root `RESOURCE-MAP.md` (broader repo scope).

---

## The meta-principle

**A staff engineer at a top-tier company does not learn "the Microsoft way." They learn the
protocol, then map vendors onto it.**

This matters concretely. If you only ever read Microsoft docs, you learn *Entra's dialect* of
OAuth and you will believe Entra-specific behaviour is how OAuth works. Then you walk into an
Okta shop, or debug a SAML integration with a Java app, or a customer asks "how does this
compare to Ping?" — and you have nothing.

Worse: Microsoft's docs are **reference** documentation, optimised for someone who already
knows the concept and needs the parameter name. Auth0 and Okta write **pedagogical**
documentation, optimised for someone learning the concept. Use each for what it's good at.

The tiering below reflects the order of authority:

```
Tier 0  Standards        ← ground truth. Vendors implement THESE.
Tier 1  Microsoft        ← the specific implementation you're certifying on
Tier 2  Hands-on         ← where knowledge becomes skill
Tier 3  Rival vendors    ← teaches the concept better + makes you portable
Tier 4  Offensive research ← how it actually breaks. THE differentiator.
Tier 5  Tools
Tier 6  Practitioners
Tier 7  Books
Tier 8  Adjacent market  ← so you can hold a conversation with a CISO
```

---

## Tier 0 — Standards and specifications

**Nobody reads these cover to cover. You read the section that answers today's question.**
The skill is knowing which document owns which answer. Citing an RFC in a design review
changes how people treat you.

### OAuth 2.0 family
| Spec | What it settles |
|---|---|
| **RFC 6749** | OAuth 2.0 Authorization Framework — the base. Read §1.3 (grant types) and §4 |
| **RFC 6750** | Bearer token usage — why `Authorization: Bearer` looks like that |
| **RFC 7636** | **PKCE** — read this one properly. §1 explains the attack it prevents |
| **RFC 8252** | OAuth for Native Apps — why mobile must use the system browser, not a webview |
| **RFC 8628** | Device Authorization Grant — the device code flow |
| **RFC 8414** | Authorization Server Metadata — the `.well-known` discovery document |
| **RFC 7662** | Token Introspection — validating opaque tokens |
| **RFC 9068** | JWT Profile for OAuth Access Tokens — standard claims in an access token |
| **RFC 9700** | **OAuth 2.0 Security Best Current Practice** — the modern consolidated guidance. If you read one, read this |

### Identity assertion
- **RFC 7519** — JSON Web Token. Sections 4.1 (registered claims) and 7 (validation) are the ones you'll reread
- **OpenID Connect Core 1.0** — openid.net. §2 (ID token) and §3 (auth flows)
- **SAML 2.0** — OASIS Core + Bindings + Profiles. Reference-only; nobody reads SAML for pleasure
- **SCIM** — RFC 7642 (requirements), **7643 (core schema)**, **7644 (protocol)**. 7643 is the one you'll actually use when mapping attributes

### Authenticators
- **W3C WebAuthn** — the passkey/FIDO2 browser API
- **FIDO Alliance CTAP2** — how the authenticator talks to the client

### Government / framework guidance ⭐
These are what you cite when a customer asks *"why should we do it this way?"* — vendor-neutral authority beats "Microsoft recommends it."

- **NIST SP 800-63** Digital Identity Guidelines — **800-63B** covers authenticator assurance levels (AAL1/2/3). *Revision 4 landed recently; check which revision your customer's compliance regime pins to before quoting it.* This is where "SMS is a restricted authenticator" comes from — a far stronger argument than "Microsoft says so"
- **NIST SP 800-207** Zero Trust Architecture — the actual definition, not the marketing one
- **CISA SCuBA** Secure Cloud Business Applications — M365 baselines, and machine-checkable (see Maester below)
- **CIS Microsoft 365 Benchmark** — the other baseline customers ask about

---

## Tier 1 — Microsoft official

### Exam logistics (verified 2026-08-09)
- **Study guide:** `aka.ms/sc300-StudyGuide` — skills measured **as of 2026-04-27**
- **Format:** 100 minutes, proctored, may include interactive/lab components
- **Renewal:** every 12 months, free online assessment
- **Free practice assessment** and **exam sandbox** — both on the certification page. Do the sandbox once so the UI isn't novel on exam day
- **Exam Readiness Zone** — 4-part "Preparing for SC-300" video series from the exam authors. Closest thing to knowing what the writers care about
- ⚠️ **Register with a personal Microsoft account, not a work/school account.** Microsoft explicitly warns that org-account exam records are **unrecoverable** if you leave that org. Given a furlough situation, this is not hypothetical

### Training
- **SC-300T00-A** — the official 4-day ILT course; **96 hours** of associated content. Its 5 modules map 1:1 to the exam domains, and the self-paced Learn versions are free
- **Microsoft Learn — Entra training hub:** `learn.microsoft.com/training/entra/`
- **Applied Skills: "Get started with identities and access using Microsoft Entra"** (APL-0501) — an **interactive lab assessment**, not multiple choice. Free, and a genuine skills check rather than a recall check. Do this *before* the exam as a readiness gate

### Documentation that's actually good
Microsoft docs vary wildly in quality. These are the strong ones:
- **Entra ID architecture & fundamentals** — `learn.microsoft.com/entra/`
- **Conditional Access docs** — genuinely excellent, including the policy templates and design guidance
- **Entra Connect Sync — "How it works" and the sync rules reference** — dense but the only real source
- **Microsoft Graph permissions reference** — the least-privilege lookup table you'll live in
- **Zero Trust deployment guidance** — `learn.microsoft.com/security/zero-trust/`
- **Entra "What's new"** — `learn.microsoft.com/entra/fundamentals/whats-new`. **Subscribe.** Identity moves monthly and stale knowledge is the failure mode this whole syllabus exists to prevent

### Official blogs
- **Microsoft Entra Blog** (techcommunity) — feature announcements, deprecations
- **MSRC / MSTIC** — vulnerability and threat intel

---

## Tier 2 — Hands-on

**Rule: no topic is "learned" until you've built it and then broken it.**

| Resource | Use |
|---|---|
| **Your own trial tenant** | Primary. Everything else is secondary |
| **`Seed-LabTenant.ps1`** (this repo) | Gives you 16 users, manager chain, dynamic groups to act on |
| **Microsoft Learn sandbox** | Free in-browser Azure for many modules — no subscription burn |
| **Graph Explorer** — `developer.microsoft.com/graph/graph-explorer` | Run Graph calls with your own token, see the raw JSON. Pairs directly with Layer 1 |
| **`jwt.ms`** | Microsoft's JWT decoder — annotates Entra-specific claims. Better than jwt.io for our purposes |
| **Practice exams** | MeasureUp (official partner), Whizlabs, Tutorials Dojo. **Use for gap-finding, never as a study source** — memorising a question bank produces someone who passes and can't do the job |
| **YouTube: "SC-300 Course - Microsoft Identity & Access Administrator"** (the playlist you linked) | Verify the upload dates before trusting any of it — anything pre-2025 predates the Entra rename, passkeys terminology, and Global Secure Access |
| **John Savill's Technical Training** (YouTube) | The reference Azure/Entra channel. His exam "study crams" are the standard recommendation, and his architecture whiteboarding is genuinely senior-level |

---

## Tier 3 — Rival vendors ⭐ (why this is not optional)

You asked specifically about Okta and Auth0. Three reasons they belong in an SC-300 plan:

1. **They teach the protocol better.** Auth0's OAuth/OIDC docs are the industry's best explainers, full stop
2. **SC-300 objective §1.3 literally requires it** — *"Configure external identity providers, including protocols such as SAML and WS-Fed."* Federating Entra with Okta is a real, tested task
3. **Customer reality.** Large enterprises run Okta for workforce SSO and Entra for M365. Migrations and coexistence are a major consulting line. Your repo already has `okta-and-third-party-idp/` — this fills it

| Resource | Why |
|---|---|
| **auth0.com/docs** — flows, and their "Which OAuth flow should I use?" decision guide | The clearest explanation of flow selection anywhere |
| **oauth.net** — maintained by Aaron Parecki (OAuth working group) | Vendor-neutral, authoritative, current |
| **Okta Developer blog** — "An Illustrated Guide to OAuth and OpenID Connect" | The single best visual explainer of the handshake |
| **Nate Barbettini — "OAuth 2.0 and OpenID Connect (in plain English)"** (conf talk, YouTube) | ~1 hour. Widely regarded as the best introduction that exists. Watch it before anything else in Layer 1 |
| **Okta docs — Universal Directory, Lifecycle Management, Okta Workflows** | Maps to Entra's ID Governance. Lets you answer "how does this compare?" |
| **Ping Identity docs** | Third major workforce IdP; common in finance and government |
| **Okta Identity Governance / SailPoint / Saviynt** | The IGA competitors to Entra ID Governance. Know the names and the positioning |

**Concept mapping — build this table in your head:**

| Entra | Okta | Auth0 | Generic |
|---|---|---|---|
| Tenant | Org | Tenant | Trust boundary |
| Enterprise Application | App Integration | Application | Service Provider / RP |
| App Registration | OIDC/API Services App | Application | OAuth Client |
| Conditional Access | Global Session Policy + App Sign-On Policy | Actions / Rules | Policy Decision Point |
| Entra Connect Sync | Okta AD Agent | — | Directory sync |
| PIM | Okta Privileged Access | — | JIT privilege elevation |
| Entitlement Management | Okta Access Requests | — | Access request / IGA |
| Managed Identity | — | M2M Application | Workload identity |

---

## Tier 4 — Offensive security research ⭐⭐ THE differentiator

**This is the tier that separates a certified administrator from someone a security team
respects.** Certification teaches you to configure. Research teaches you what an attacker does
with your configuration. You cannot defend Conditional Access without knowing how CA is bypassed.

### Dirk-jan Mollema — **dirkjanm.io** (Outsider Security)
The foremost independent Entra ID security researcher. ~7 years on Entra, a decade on AD.
Start with:
- **"Finding Entra ID CA bypasses — the structured way"** — read this *while* you build CA policies. It will change how you write them
- **"Advanced Active Directory to Entra ID lateral movement techniques"** — Black Hat USA 2025 / DEF CON 33. The definitive hybrid-identity attack-path material, which is exactly your Layer 2 §1.4
- **CVE-2025-55241** ("Death by Token") — an Actor-token flaw he found in July 2025 that could have compromised **any** M365 tenant. Read the writeup as a case study in why token internals (Layer 1 §4) are not academic

### Others worth following
- **Nestori Syynimaa / @DrAzureAD** — **AADInternals**, the deepest public Entra internals toolkit and documentation
- **SpecterOps** — BloodHound, Azure/Entra attack-path research
- **MITRE ATT&CK** — the Cloud and Azure AD matrices. Map every CA policy you write to a technique it mitigates. That's how you justify controls to a CISO
- **Invictus IR** — cloud incident response; their work on `AADGraphActivityLogs` (detecting legacy Azure AD Graph abuse) is directly relevant to Domain 4 monitoring
- **Practical365** — strong deep-dive analysis, including the CVE-2025-55241 breakdown

> **A note on framing.** These are dual-use. Study them to build detections and harden
> configurations — that's the defensive value and it's exactly why blue teams read them.
> Run tooling only against tenants you own or are contracted to test.

---

## Tier 5 — Tools

### Assessment & posture ⭐
- **Maester** — `maester.dev` / `github.com/maester365/maester`. **Learn this one.** Pester-based test framework that treats tenant config as code. Ships 40+ tests from **EIDSCA** (Entra ID Security Config Analyzer) plus **CISA SCuBA**, **CIS M365**, and **ORCA** baselines, and runs in GitHub Actions / Azure DevOps / GitLab pipelines.

  Why it matters for *you specifically*: it is the bridge between your identity work and your
  DevSecOps/platform-engineering goal. "I have Entra config drift gated in CI" is a portfolio
  artifact, not a certificate. Run it against your trial tenant on day one to get a baseline,
  then again after each lab to watch your posture score move.
- **ZeroTrustAssessment** and **EntraExporter** — companion tooling, config export and ZT gap analysis
- **ScubaGear** (CISA) — the official SCuBA assessment tool
- **Monkey365** — M365/Azure security review

### Research & recon (own-tenant only)
- **ROADtools** (`dirkjanm/ROADtools`) — `roadlib` + **`roadrecon`** (dumps users/groups/devices/roles/SPs to a local DB with a web GUI for offline attack-path exploration) + **`roadtx`** (token exchange, PRT handling, device registration)
- **AADInternals** — PowerShell, deep internals
- **AzureHound / BloodHound** — attack-path graphing

### Daily driver
- **Microsoft Graph PowerShell SDK** (installed — v2.39.0)
- **Graph X-Ray** (browser extension, by Merill) — shows the Graph calls the portal makes as you click. **Outstanding learning tool**: do a thing in the portal, watch the API call, then script it
- **`jwt.ms`**, **Graph Explorer**, **Azure CLI / Az PowerShell** (installed)

---

## Tier 6 — Practitioners to follow

Identity changes monthly. These people surface what matters before it hits docs.

| Who | Where | Focus |
|---|---|---|
| **Merill Fernando** | `merill.net`, **entra.news** | Microsoft PM; creator of Maester and Graph X-Ray. The single highest-signal Entra newsletter |
| **Thomas Naunheim** | `cloud-architekt.net` | Entra security architecture, workload identity, PIM — the most rigorous architecture writing in the space |
| **Daniel Chronlund** | `danielchronlund.com` | Conditional Access automation, CA-as-code |
| **Jan Bakker** | `janbakker.tech` | Authentication methods, passwordless, CA |
| **Sami Lamppu** | `samilamppu.com` | Entra monitoring, detection engineering |
| **John Savill** | YouTube | Azure/Entra architecture and exam prep |
| **Practical365 / Office365ITPros** | blogs | Deep operational analysis |

---

## Tier 7 — Books

- **"OAuth 2 in Action"** — Justin Richer & Antonio Sanso. You build an OAuth server and client by hand. Nothing else produces the same depth
- **"Solving Identity Management in Modern Applications"** — Wilson & Hingnikar. Vendor-neutral identity architecture
- **"Zero Trust Networks"** — Gilman & Barth (O'Reilly). The concept before the marketing
- **"Microsoft Entra ID / Azure AD" administration titles** — check publication date ruthlessly; anything pre-2024 predates the rename and much else

---

## Tier 8 — Adjacent market (so you can talk to a CISO)

You asked about SentinelOne. It isn't SC-300 content — but knowing where it sits is what lets
you hold a strategy conversation instead of a configuration one.

| Category | Microsoft | Competitors | Why you care |
|---|---|---|---|
| **ITDR** (identity threat detection) | Defender for Identity, Entra ID Protection | **CrowdStrike Falcon Identity Protection**, **SentinelOne Singularity Identity**, Silverfort | Customers ask "we already have CrowdStrike — do we need Defender for Identity?" You need an answer |
| **EDR/XDR** | Defender for Endpoint / XDR | **SentinelOne**, CrowdStrike, Palo Alto Cortex | Device-compliance CA depends on an EDR signal reaching Intune |
| **PAM** | PIM (directory-scoped only) | **CyberArk**, **Delinea**, BeyondTrust | PIM does *not* cover server/DB/secret PAM. Knowing the gap prevents overselling — and **Delinea is Microsoft's named migration partner** for retired Entra Permissions Management |
| **IGA** | Entra ID Governance | **SailPoint**, **Saviynt**, Okta IG | Entra ID Governance is newer; enterprises often already own SailPoint |
| **CASB** | Defender for Cloud Apps | Netskope, Zscaler | SC-300 §3.4 is MDA specifically |
| **SSE/ZTNA** | Global Secure Access | **Zscaler**, Netskope, Cloudflare | GSA is Microsoft's late entry; customers usually have an incumbent |
| **SIEM** | Sentinel | Splunk, Elastic, Chronicle | Where your diagnostic settings ship to |
| **Secrets** | Key Vault | HashiCorp Vault | Multi-cloud customers standardise on Vault |

---

## How to actually sequence this

Do **not** read this top to bottom. Order by leverage:

| # | Do this | Time |
|---|---|---|
| 1 | Nate Barbettini's OAuth/OIDC talk | 1 hr |
| 2 | Auth0 flows docs + `oauth.net` | 2 hrs |
| 3 | **RFC 7636 (PKCE) §1** and **RFC 7519 (JWT) §4.1** | 1 hr |
| 4 | Layer 1 labs in your own tenant — decode a real JWT | 3 hrs |
| 5 | **Run Maester against your tenant.** Baseline your posture | 1 hr |
| 6 | MS Learn SC-300 paths + official docs, domain by domain | bulk |
| 7 | Dirk-jan's CA-bypasses paper — *while* building CA policies | 2 hrs |
| 8 | Applied Skills APL-0501 lab as a readiness gate | 2 hrs |
| 9 | Practice assessment — gap-finding only | 1 hr |
| 10 | Okta/Auth0 comparison table, from memory | ongoing |

**Steps 1–5 before step 6.** Protocol first, then vendor. Reversing that is how people end up
knowing which blade to click and nothing about why.

---

## Currency check — run this monthly

Identity is the fastest-moving surface in the Microsoft stack. Anything here can go stale.

1. **Entra "What's new"** — `learn.microsoft.com/entra/fundamentals/whats-new`
2. **entra.news** (Merill's newsletter)
3. **SC-300 study guide change log** — Microsoft publishes a diff table per revision
4. **Re-run Maester** — catches drift *and* newly-added baseline tests

**Staleness tells.** If a resource says *"Azure AD"*, uses *`Connect-MsolService`* or
*`Connect-AzureAD`*, says *"FIDO2"* without *"passkeys"*, or mentions **Entra Permissions
Management** as current — it predates 2025/26 and the rest of it is suspect too.

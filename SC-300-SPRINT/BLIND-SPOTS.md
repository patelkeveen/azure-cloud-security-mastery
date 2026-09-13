# SC-300 blind spots — what your revision material does not contain

**Built 2026-09-14. Exam Friday 18 September 2026, 07:30 IST.**
Blueprint verified live the same day: *skills measured as of 27 April 2026* —
<https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-300>

---

## The finding

**Your domain names and weights are correct.** D1 20–25%, D2 25–30%, D3 20–25%, D4 20–25% match the
live guide exactly, and SC-300 was *not* restructured in July 2026 — that was SC-200. The April 2026
revision changed no group names, added none, removed none, and altered no weights. Five skill groups
carry a "Minor" edit and one, Global Secure Access, is marked "No change", meaning it was already on
the exam before April.

**But three entire live skill groups have zero coverage in the four `EXPLAIN/` files you revise from**,
and they sit inside your three largest domains:

| Missing skill group | Lives in | Domain weight |
|---|---|---|
| **Implement Global Secure Access** | D2 Authentication & access | **25–30%** |
| **Manage and monitor app access by using Microsoft Defender for Cloud Apps** | D3 Workload identities | 20–25% |
| **Monitor identity activity by using logs, workbooks, and reports** | D4 Governance | 20–25% |

Each domain has four skill groups. If items were spread evenly — they are not, but as a first
approximation — that is roughly **one quarter of three domains, or about 15–18% of the paper**, on
material your revision files never mention.

**This file is that material.** Read it Monday and Tuesday. It is the single highest-value thing you
can do with the four days, because everything else in your pack is revision of things you already
half-know, and this is not.

> **One honesty note.** The adversarial verification pass for this sprint was killed by a monthly
> spend limit, so the facts below were gathered but not independently refuted by a second pass.
> Distinctions and mechanisms are reliable. **Treat specific numbers as "check on Learn if you are
> about to bet the question on it"**, and prefer the reasoning to the digit.

---

# 1. Global Secure Access — D2, and completely absent locally

## What it is, in one paragraph

Global Secure Access is Microsoft's **Security Service Edge** — its answer to Zscaler and Netskope.
It moves network access decisions into the identity plane, so Conditional Access can evaluate not
just *are you allowed to sign in to this app* but *are you allowed to reach this network resource at
all*. It is the modern replacement for VPN and for Application Proxy's private-app role.

It has **two products** under one roof, and the exam tests which one you pick:

| | **Microsoft Entra Private Access** | **Microsoft Entra Internet Access** |
|---|---|---|
| Protects | **Your own internal apps and resources** (the VPN replacement) | **Traffic going out to the internet and SaaS** |
| Replaces | VPN, and Application Proxy for non-web apps | Secure web gateway / proxy |
| Needs | A **private network connector** on a machine inside your network | No connector — traffic is forwarded from the client |
| Handles | Any TCP/UDP app, not just HTTP | Web filtering, threat protection |

There is a third thing you must not conflate with Internet Access generally:
**Internet Access for Microsoft 365** is a *separate traffic forwarding profile* that sends
Microsoft 365 traffic through GSA specifically so you can apply **compliant network** checks and get
tenant restrictions. It is enabled independently of the wider Internet Access profile.

## Traffic forwarding profiles — the central concept

GSA works by **forwarding profiles**. You turn on a profile, and the GSA client (or a remote network
such as a branch router) sends matching traffic to Microsoft's edge, where policy is applied.

Three profiles, and the exam wants you to match profile to purpose:

1. **Microsoft 365 profile** — Exchange, SharePoint, Teams traffic
2. **Private access profile** — your internal apps, via the connector
3. **Internet access profile** — everything else going to the internet

## The feature that ties GSA back to identity, and the likeliest exam item

**Compliant network check.** Once traffic flows through GSA, Conditional Access gains a condition —
*Network* → *Compliant network* — that means "this session arrived through our GSA tenant." You then
build a CA policy that says a sensitive app can only be reached from a compliant network.

**Why this is the exam-worthy part:** it is a network control that *cannot be spoofed by IP*. The old
answer to "only allow access from the corporate network" was a named location with a trusted IP
range, and an attacker on a VPN could imitate it. The compliant network check is bound to the
authenticated GSA tenant, not to an address.

> **Exam tell:** *"restrict access to the corporate network without relying on IP addresses"* or
> *"users are bypassing the trusted-location policy with a commercial VPN"* → **compliant network
> check via Global Secure Access**, not a named location.

**Universal tenant restrictions** is the sibling feature: it stops users signing in to *other*
tenants' instances of Microsoft 365 from your managed devices or network — the data-exfiltration
control for "employee signs into their personal OneDrive on a corp laptop."

## Licensing, because the exam asks

GSA Private Access and Internet Access are **Microsoft Entra Suite** (or standalone GSA licences) —
**not** included in P1 or P2. Internet Access for Microsoft 365 and the Microsoft 365 traffic
forwarding profile are available more broadly with Entra ID P1.

> **Tell:** if a stem gives you only P1/P2 and asks for full internet filtering, the licence is the
> constraint, and "acquire Entra Suite" may itself be the right answer.

## What you must be able to say out loud

- Private Access = internal apps, needs a connector, replaces VPN.
- Internet Access = outbound web/SaaS, filtering and threat protection.
- Compliant network check = CA condition proving the session came through GSA, unspoofable by IP.
- Universal tenant restrictions = stop sign-ins to other tenants.
- Licensing = Entra Suite, not P2.

---

# 2. Microsoft Defender for Cloud Apps — D3, and completely absent locally

This is a whole skill group in a 20–25% domain, with **seven bullets**. It is the CASB.

## The four pillars, in the order the product works

**1. Cloud discovery — "what SaaS are people actually using?"**
MDCA ingests firewall/proxy logs and tells you which cloud apps appear in them. Two modes:

- **Snapshot report** — you upload a log file manually, one-off.
- **Continuous report** — a **log collector** (a Docker container you host) or **Defender for
  Endpoint integration** feeds logs automatically and keeps the picture live.

> **Tell:** *"ongoing visibility with no manual upload"* → continuous report, and if the estate is
> already on Defender for Endpoint, the answer is the **MDE integration**, because it needs no
> collector infrastructure.

Discovered apps are scored against the **cloud app catalog** — 31,000+ apps rated on ~80 risk factors
(compliance certifications, security controls, legal). You can **sanction** or **unsanction** an app;
unsanctioning can push a block to Defender for Endpoint.

**2. Connected apps — API connectors**
Connecting an app (Microsoft 365, Google Workspace, Salesforce, Box, AWS…) via its API gives
**after-the-fact** visibility and control: scan files at rest, see who shared what, revoke a sharing
link, suspend a user. It is deep but not real-time.

**3. Conditional Access App Control — the session proxy**
This is the one that matters most for SC-300 because **it is configured from Conditional Access**,
not from MDCA. In a CA policy you set *Session* → *Use Conditional Access App Control*, and the
user's session is reverse-proxied through MDCA. That enables:

- **Access policies** — allow or block the *session* based on device, location, app, user
- **Session policies** — act *inside* the session in real time: block download, block upload,
  block copy/paste, apply a sensitivity label on download, monitor only

> **The distinction the exam tests:** an **access policy** decides whether the session happens at
> all; a **session policy** controls what you can do once inside it. *"Allow access from unmanaged
> devices but prevent downloading files"* is the canonical stem, and the answer is **CA App Control
> with a session policy blocking downloads.**

**4. App governance / OAuth app policies — the non-human identity control**
MDCA inventories **OAuth applications** users have consented to, with their permission scopes and a
risk level, and lets you **ban an app** and revoke its consent. This is the detection half of the
*illicit consent grant* attack.

> **Tell:** *"a third-party app has been granted broad Mail.Read across the tenant, find and revoke
> it"* → MDCA OAuth app policies.

## The one you keep separate: application-enforced restrictions

CA also has *Session* → **Use app enforced restrictions**, which is **not** MDCA. Entra passes the
device state to the app (Exchange Online, SharePoint Online) and *the app itself* imposes limited
web-only access. No proxy, no MDCA licence, but only works for apps that support it.

> **Tell:** *"SharePoint should give browser-only access on unmanaged devices"* with no mention of a
> proxy → **app-enforced restrictions**. *"Block downloads in any SaaS app"* → **CA App Control**.

---

# 3. Monitor identity activity — D4, and completely absent locally

Four things, and the boundaries between them are the exam.

## The three log types

| Log | Answers | Typical stem |
|---|---|---|
| **Sign-in logs** | Who authenticated, from where, to which app, which CA policies applied and their result | *"Why was this user blocked?"* |
| **Audit logs** | What changed in the directory, and who changed it | *"Who deleted the group / modified the CA policy?"* |
| **Provisioning logs** | What SCIM/HR-driven provisioning did to each object and why it skipped some | *"Why was this user not created in the SaaS app?"* |

Sign-in logs are further split into **interactive**, **non-interactive**, **service principal** and
**managed identity** sign-ins — and *the service-principal tab is where you investigate workload
identity abuse*. Practitioners forget the non-interactive tab exists; the exam does not.

## Retention — the number that drives the architecture answer

Entra keeps these logs for a **limited window that depends on licence** — roughly **7 days on Free
and 30 days with P1/P2**. Anything longer, or any custom query, means exporting.

## Diagnostic settings — the export

Entra ID → Monitoring → **Diagnostic settings** sends the logs to one of three destinations, and the
exam wants you to match destination to requirement:

| Destination | Use it when the requirement is |
|---|---|
| **Log Analytics workspace** | Query with **KQL**, build **workbooks**, alert |
| **Storage account** | Cheap long-term **archive** / compliance retention |
| **Event Hub** | Stream to a **third-party SIEM** (Splunk, QRadar) |

> **Tell:** *"retain for two years at lowest cost"* → storage account. *"run queries and build
> dashboards"* → Log Analytics. *"send to our existing Splunk"* → Event Hub.

## Workbooks and KQL

Once in Log Analytics, Entra ships **workbook templates** — sign-ins by location, CA gaps, legacy
authentication, sign-ins by risk. The audience profile for SC-300 says candidates should be able to
read KQL, so expect to *recognise* a query rather than author one:

```kql
SigninLogs
| where TimeGenerated > ago(7d)
| where ResultType != 0
| summarize FailedAttempts = count() by UserPrincipalName, ResultType
| order by FailedAttempts desc
```

You already know this shape from SC-200 preparation. **The table names are the transferable part:**
`SigninLogs`, `AuditLogs`, `AADNonInteractiveUserSignInLogs`, `AADServicePrincipalSignInLogs`,
`AADProvisioningLogs`, `AADRiskyUsers`, `AADUserRiskEvents`.

## Identity Secure Score

A percentage with **improvement actions**, scoped to identity only, inside Entra. Distinguish from
**Microsoft Secure Score**, which spans identity, devices, apps and data across M365.

> **Tell:** if the stem is only about Entra posture → Identity Secure Score. You raised a Secure
> Score from the low 60s to 82.97 in production, so the concept is familiar — just be precise about
> *which* score the question means.

---

# 4. Rapid-fire — the partial gaps, ranked by likelihood

These exist in your material but thinly, or are missing single high-value facts.

## D2 — authentication and access

**Security defaults.** Absent from the D2 explainer, and the *security defaults vs Conditional
Access* pair is close to a guaranteed item. Free, tenant-wide, no customisation: MFA registration for
all, MFA for admins, MFA for Azure management, block legacy auth, block device-code flow for new
tenants. **Mutually exclusive with CA** — you must turn them off to use CA.

**Protected actions.** P1. Attaches an **authentication context** to specific high-risk directory
*permissions* (deleting a CA policy, changing cross-tenant settings) so performing that action
re-prompts for a stronger auth. Not a role, not a policy on an app — a control on an *operation*.

**Authentication context.** Up to 99 values (`c1`–`c99`), published to apps, referenced by CA. Used
by protected actions, SharePoint sensitivity labels and PIM activation.

**CA templates and Microsoft-managed policies.** Templates come in six categories and deploy in
**report-only** by default. Microsoft-managed policies are the ones Microsoft rolls out to tenants
automatically (MFA for admins etc.) and which you can exclude break-glass accounts from.

**Registration campaigns.** Nudge users on sign-in to register a stronger method. Three states:
Microsoft managed / Enabled / Disabled. One target method at a time; snooze is configurable.

**Certificate-based authentication.** Free — no P1. Replaces AD FS for federated CBA. Can be
single-factor or multifactor depending on the policy binding; username binding rules and issuer
trust matter.

**Entra Kerberos for hybrid identities.** Enables cloud Kerberos trust for Windows Hello for
Business and for Azure Files. Module `AzureADHybridAuthenticationManagement`.

**Risky workload identities.** ID Protection for service principals — detections include leaked
credentials, anomalous sign-ins, suspicious API traffic. **Needs Workload Identities Premium**, a
separate SKU, and CA for workload identities is **block-only**, single-tenant service principals,
no groups.

**Disable account and revoke sessions — the concrete sequence.** Disable sign-in, revoke refresh
tokens (`Revoke-MgUserSignInSession`), reset the password, remove registered auth methods. Revoking
tokens is what makes it immediate; disabling alone leaves valid access tokens until expiry — unless
**CAE** is in play, which is the whole point of CAE.

## D1 — user identities

**Cross-tenant synchronization.** Push model: the *source* tenant configures outbound sync, the
*target* tenant must enable inbound *"Allow users sync into this tenant."* Creates B2B members
automatically. Distinct from cross-tenant *access* settings (trust) and from external collaboration
settings (who may invite).

**Custom security attributes.** Tenant-level, defined in attribute sets, assigned to users and
service principals, and usable in **dynamic group rules** and ABAC. Requires dedicated roles
(Attribute Definition Administrator, Attribute Assignment Administrator) — **Global Admin does not
have them by default**, which is exactly the kind of thing SC-300 asks.

**Device join vs registration vs hybrid join.** Registered = personal device, work account added.
Entra joined = cloud-owned corporate device. Hybrid joined = on-prem AD domain-joined *and*
registered in Entra. Drives which CA device conditions can apply.

**Two corrections to your local material**, flagged by the research pass and worth verifying before
you rely on either:
- The claim *"Cloud Sync has no Exchange hybrid writeback"* appears to be out of date — the current
  decision matrix shows Exchange hybrid attributes supported by both.
- The claim *"usage location must be set or licence assignment fails"* is too absolute for
  group-based licensing, where users can inherit a usage location.

## D3 — workload identities

**App roles.** Declared in the app registration manifest with allowed member types *Users/Groups* or
*Applications*, a value string, and enable/disable. Assigned from the **enterprise application**, not
the registration. App-only roles land in the `roles` claim.

**Application collections.** My Apps launchers grouping apps for users. P1/P2.

**Managed service accounts (gMSA/sMSA/dMSA).** On-premises Windows constructs for services, with
automatic password management. **Not** a cloud identity — the exam offers them against managed
identities to test whether you know which side of the boundary the workload sits on.

**Assignment required.** On an enterprise app, forces explicit user/group assignment for token
issuance and forces admin consent.

---

# 5. How to use this file across four days

| When | Do |
|---|---|
| **Monday** | §1 Global Secure Access and §3 Monitor identity activity, out loud. These are the two biggest holes and they are both conceptual, not lab-dependent |
| **Tuesday** | §2 Defender for Cloud Apps in full — the access-policy vs session-policy distinction until it is automatic |
| **Wednesday** | §4 rapid-fire, twice. Then the practice assessment, and score which of these appear |
| **Thursday** | The tells only. Cover the left column, say the tell |

**Do not try to lab any of this.** Global Secure Access needs Entra Suite and a connector host,
MDCA needs a licence you no longer hold, and diagnostic settings need an Azure subscription with
credit. All three are examinable as *decision models*, and the decision model is what this file
contains.

> **Related:** [`DISCRIMINATORS.md`](DISCRIMINATORS.md) — 83 confusion pairs with exam tells ·
> [`FINAL-FOUR.md`](FINAL-FOUR.md) — the four-day plan and the 07:30 protocol ·
> [`GAP-DRILL.md`](GAP-DRILL.md) · [`EXPLAIN/`](EXPLAIN/)

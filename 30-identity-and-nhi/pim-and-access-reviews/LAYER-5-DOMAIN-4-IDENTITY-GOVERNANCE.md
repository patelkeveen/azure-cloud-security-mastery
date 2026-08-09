# Layer 5 — SC-300 Domain 4: Plan and Automate Identity Governance (20–25%)

> Completes the exam-domain coverage. Layers 1–4 were about *granting* access; this is about
> **proving it's still justified** — the layer auditors, regulators and CISOs actually care about.
>
> **Gate:** you own this layer when you can design a break-glass pair from memory and defend
> every property of it, explain the PIM assignment matrix without hedging, and write KQL against
> `SigninLogs` that answers a real question.
>
> Licensing and retention figures verified against Microsoft documentation on **2026-08-09**.

---

## 1. Licensing reality check — read this before planning any lab ⚠

**Identity governance is split across two SKUs, and the split is not intuitive.** Getting this
wrong means promising a customer a feature they can't license, or building a lab you can't run.

| Feature | P2 | Entra ID Governance |
|---|:---:|:---:|
| **PIM** (Entra roles, Azure resources) | ✅ | ✅ |
| **PIM for Groups** | ✅ | ✅ |
| **PIM Conditional Access controls** (auth context on activation) | ✅ | ✅ |
| Entitlement management — core | ✅ | ✅ |
| EM — groups, apps, SharePoint sites in packages | ✅ | ✅ |
| EM — multi-stage approvals, specific/manager approvers | ✅ | ✅ |
| EM — **separation of duties** | ✅ | ✅ |
| EM — expiration, external user lifecycle | ✅ | ✅ |
| Access reviews — core | ✅ | ✅ |
| **Lifecycle Workflows** | ❌ | ✅ |
| LCW custom extensions (Logic Apps) | ❌ | ✅ |
| EM — auto-assignment policies | ❌ | ✅ |
| EM — custom extensions, Verified ID / ID Protection / Insider Risk integration | ❌ | ✅ |
| EM — Entra roles in access packages | ❌ | ✅ |
| AR — ML-assisted certifications, inactive-user-only scoping | ❌ | ✅ |
| Insights — inactive guest accounts | ❌ | ✅ |

**Corrections to earlier assumptions in this repo:** PIM for Groups is **P2**, not Governance-only.
Separation of duties and multi-stage approvals are **P2**. **Lifecycle Workflows genuinely
requires the Governance SKU** — that flag was right.

> **The strategic sentence, straight from Microsoft:** *"All currently Generally Available
> features in Microsoft Entra ID P2 will remain, but no new Identity Governance &
> Administration features or capabilities will be added to the Microsoft Entra ID P2 SKU."*
>
> P2 governance is frozen. Everything new lands in ID Governance or Entra Suite. That's the
> answer when a customer asks "do we need the add-on?" — today maybe not; in two years yes.

**Two billing traps:**

- **Licence counting is by population in scope, not by admin.** An access review of a 500-member
  group with 3 reviewers needs **503** licences. An access package that 2,000 employees *can
  request* needs 2,000 — even if only 150 request it.
- **Guest governance uses Monthly Active User billing and requires an Azure subscription.** Any
  guest with one or more governance actions that month appears on the bill. Surprises customers
  who assumed guests were free.

---

## 2. Entitlement management

**The model:** *catalog* (container of resources) → *access package* (a bundle of resource roles)
→ *policy* (who can request, who approves, how long it lasts).

The point is delegation. A catalog owner — usually a business owner, not IT — curates what
exists; requesters self-serve; approvers decide. **IT stops being a ticket queue for access.**

| Concept | Notes |
|---|---|
| **Catalog** | Container + delegation boundary. Catalog owners manage without directory-wide rights |
| **Access package** | Groups, teams, apps, SharePoint sites — bundled as a job function |
| **Policy** | Who may request; approval stages; expiry. Multiple policies per package for different populations |
| **Multi-stage approval** | Up to several stages, with alternate approvers if nobody acts |
| **Separation of duties** | Mark packages incompatible — someone holding one **cannot request** the other |
| **Connected organizations** | Partner domains/tenants whose users may request |
| **Terms of use** | Attestation before access; auditable record |

**Separation of duties is the control that answers SoX and SOC 2 questions.** "Nobody can hold
both Payments-Submit and Payments-Approve" is enforced at request time, not discovered in an
audit six months later. Reach for this rather than trying to express SoD through custom roles.

**External user lifecycle** — a guest brought in *via* an access package can be automatically
blocked and deleted when the assignment expires. That closes the standard finding: partner
guests from a project that ended in 2023 still holding access today.

---

## 3. Access reviews

**The hard part isn't configuration. It's picking the reviewer.**

| Reviewer | Good for | Failure mode |
|---|---|---|
| **Manager** | Broad periodic recert | Rubber-stamping — managers rarely know what a group grants |
| **Group/app owner** | Access to *their* resource | Owner may not know the person |
| **Self-review** | Cheap, wide coverage | Nobody removes their own access |
| **Selected users** | Privileged roles | Doesn't scale |

Realistic design: **owner-reviews for high-value resources, manager-reviews for breadth,
self-review only where the risk is low.**

**Settings that decide whether it works:**

- **Auto-apply** — without it, decisions are recorded and *nothing happens*. This is the single
  most common reason an organisation "does access reviews" and access never actually changes.
- **If reviewers don't respond** — No change / Remove access / Approve access. **"Approve
  access" on no-response makes the whole exercise theatre.** Pick Remove or No change and mean it.
- **Decision helpers** — surface last sign-in so reviewers see who's dormant. Recommendations
  based on inactivity are P2; ML-assisted user-to-group affiliation needs Governance.
- **Recurrence** — quarterly is the usual regulatory cadence.

The output is the **audit evidence**: who reviewed, what they decided, when, and what was
applied. That artifact is what gets handed to an assessor.

---

## 4. Privileged Identity Management ⭐

### The assignment matrix — two axes, not one

Most people think the choice is "eligible vs active." It's a 2×2:

| | **Permanent** | **Time-bound** |
|---|---|---|
| **Eligible** | Can activate any time, indefinitely | Can activate, but only until a date |
| **Active** | Standing access. **The thing PIM exists to eliminate** | Standing access with an expiry |

**Target state: eligible + time-bound for humans.** Permanent active should exist only for
break-glass. Being able to draw this grid is a fast way to demonstrate you've operated PIM
rather than read about it.

### Activation settings

| Setting | Why |
|---|---|
| Max activation duration | Shortest that permits the work — often 2–4 hours |
| Require MFA on activation | Baseline |
| **Require Conditional Access authentication context** | **Stronger.** Bind activation to `c1` and demand phishing-resistant strength (Layer 3 §3.3). Elevation now needs a passkey, not a push |
| Require justification | Audit trail |
| Require ticket information | Ties elevation to a change record |
| Require approval | For the highest roles. Name specific approvers, not "anyone" |
| Notifications | Alert on activation of the top roles |

### PIM for Groups

Make a group PIM-managed and **membership itself becomes just-in-time.** This is the workaround
for everything without native PIM support: a group granting a SaaS app role, an Azure RBAC
assignment, an on-prem-synced group. Confirmed **P2** — no add-on required.

### PIM for Azure resources

Scoped at management group / subscription / resource group / resource — which is why Layer 0's
Azure hierarchy matters. Same eligible/active model applied to Owner, Contributor, etc.

### What happens when the licence lapses ⚠ — a genuine security finding

Verified behaviour when P2 or Governance expires (including **trial expiry**):

- Active **permanent** assignments — unaffected
- Active **time-bound** assignments — **become permanent.** They stop expiring
- **Eligible assignments are removed entirely** — nobody can activate
- Access reviews end; PIM configuration settings are removed

Read that second bullet again. **A lapsed licence silently converts time-bound admin access into
standing permanent admin access**, while simultaneously removing the just-in-time path everyone
was relying on. Anyone whose privilege came from eligibility loses it; anyone with time-bound
active access keeps it forever.

This matters to you concretely: **when your trial ends, this happens in your lab tenant.** It's
also a first-class discovery question — *"what's your PIM licence renewal date, and who checks it?"*

### Break-glass accounts — the definitive pattern

Referenced from Layer 3 §3.6. Every property has a reason:

| Property | Why |
|---|---|
| **At least two** | One lost or compromised credential must not be a lockout |
| **Cloud-only**, `*.onmicrosoft.com` | Survives federation failure, Connect Sync failure, custom-domain misconfiguration (Layer 2 §1.1) |
| **Permanent active Global Administrator — NOT PIM-eligible** | **PIM may be the thing that's broken, or its licence may have lapsed.** An account that must activate through PIM is not break-glass |
| **Excluded from every Conditional Access policy** | CA misconfiguration is the most common lockout cause |
| No dependency on one MFA method or one person's phone | The phone breaks, or the person leaves |
| Long random passwords, **split between custodians**, physically secured | No single person can act alone |
| **Alerting on any sign-in** | These should never be used. Use is an incident |
| **Tested on a schedule** | An untested recovery path is a hope, not a control |

The "not PIM-eligible" line is the one people get wrong, and it's the one that matters most —
because the scenarios where you need break-glass are exactly the scenarios where PIM is
unavailable.

---

## 5. Monitoring, logs, and KQL ⭐ `[SHALLOW]`

The audience profile says you should be "familiar with KQL." The exam barely tests it. **The job
uses it daily.** This section is disproportionately valuable.

### There are four sign-in log tables, and most people know one

| Table | Contains |
|---|---|
| `SigninLogs` | **Interactive** user sign-ins |
| `AADNonInteractiveUserSignInLogs` | Token refreshes, background client auth — **usually the highest volume by far** |
| `AADServicePrincipalSignInLogs` | App-only sign-ins (Layer 4) |
| `AADManagedIdentitySignInLogs` | Managed identity token acquisition |

Plus `AuditLogs` (directory changes), `AADProvisioningLogs` (SCIM), `AADRiskyUsers`,
`AADUserRiskEvents`, `IdentityInfo`.

**Investigating a compromise using only `SigninLogs` misses three quarters of the picture** —
notably the service principal activity where modern attackers persist.

### Retention — verified, and it's not what most people assume

| Report | Free | P1 | P2 |
|---|---|---|---|
| Audit logs | **7 days** | 30 days | 30 days |
| Sign-in logs | **7 days** | 30 days | 30 days |
| MFA usage | 30 days | 30 days | 30 days |
| **Risky sign-ins** | 7 days | 30 days | **90 days** |
| **Risky users** | **No limit** | No limit | No limit |

Three things worth internalising: **Free is 7 days, not 30**; **risky sign-ins get 90 days on
P2** — longer than ordinary sign-ins; and **risky users are never aged out until the risk is
remediated**, which is why unremediated risk accumulates visibly.

> **Retention changes are not retroactive.** Upgrading Free → P2 does not recover expired data.
> If a customer suspects a breach three months old and never configured diagnostic settings,
> **the data is gone.** Configuring log export is therefore not a nice-to-have; it's the
> difference between having an investigation and not having one.

### Diagnostic settings — the fix

Route logs to **Log Analytics** (query with KQL), **Storage** (cheap long-term archive), or
**Event Hub** (stream to a third-party SIEM). Send the categories you'll actually use:
`SignInLogs`, `NonInteractiveUserSignInLogs`, `ServicePrincipalSignInLogs`,
`ManagedIdentitySignInLogs`, `AuditLogs`, `ProvisioningLogs`, `RiskyUsers`,
`UserRiskEvents`.

Cost is driven by ingestion volume, and non-interactive sign-ins dominate. Model it before
enabling everything in a large tenant.

### A starter query library

**Failed sign-ins by error code**
```kusto
SigninLogs
| where TimeGenerated > ago(7d) and ResultType != 0
| summarize Attempts = count(), Users = dcount(UserPrincipalName)
    by ResultType, ResultDescription
| sort by Attempts desc
```

**Conditional Access failures — which policy, which control**
```kusto
SigninLogs
| where TimeGenerated > ago(24h)
| mv-expand ca = ConditionalAccessPolicies
| where ca.result == "failure"
| project TimeGenerated, UserPrincipalName, AppDisplayName,
          Policy = tostring(ca.displayName), Location = LocationDetails.city
| sort by TimeGenerated desc
```

**Legacy authentication still in use — write this before you enforce a block**
```kusto
SigninLogs
| where TimeGenerated > ago(30d)
| where ClientAppUsed in ("Exchange ActiveSync","IMAP4","POP3","SMTP","Other clients",
                          "Authenticated SMTP","MAPI Over HTTP","Exchange Web Services")
| summarize Count = count(), Apps = make_set(AppDisplayName)
    by UserPrincipalName, ClientAppUsed
| sort by Count desc
```

**Privileged role activations (PIM)**
```kusto
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has "Add member to role completed (PIM activation)"
| extend Role = tostring(TargetResources[0].displayName)
| project TimeGenerated, Role,
          Actor = InitiatedBy.user.userPrincipalName, Result
| sort by TimeGenerated desc
```

**Break-glass account use — this should return nothing**
```kusto
union SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(90d)
| where UserPrincipalName startswith "breakglass"
| project TimeGenerated, UserPrincipalName, AppDisplayName,
          IPAddress, ResultType
```
Wire that to an alert rule. A hit is an incident.

**Consent grants — illicit consent hunting (Layer 1 §6)**
```kusto
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has "Consent to application"
| extend App = tostring(TargetResources[0].displayName)
| project TimeGenerated, App,
          Actor = InitiatedBy.user.userPrincipalName,
          Detail = TargetResources[0].modifiedProperties
| sort by TimeGenerated desc
```

**Service principal sign-ins from unexpected locations**
```kusto
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d) and ResultType == 0
| summarize Countries = make_set(LocationDetails.countryOrRegion),
            Signins = count()
    by ServicePrincipalName, AppId
| where array_length(Countries) > 1
| sort by Signins desc
```

> **Correlate on `oid`, not UPN** (Layer 1 §4). UPNs change; object IDs don't. Guest UPNs are
> `#EXT#`-mangled (Layer 2 §1.3) and will not join cleanly.

### Workbooks and Identity Secure Score

Built-in workbooks — Sign-ins, **Conditional Access Gap Analysis**, Sensitive Operations — are a
fast first read on an unfamiliar tenant.

**Identity Secure Score** is best used as a *customer-facing roadmap artifact*: a scored,
Microsoft-authored list of improvements with impact estimates. Screenshot it at engagement
start, act, screenshot at the end. That before/after is how you demonstrate value to someone who
doesn't read KQL.

---

## 6. Troubleshooting

**"Access review completed but nobody lost access"** → auto-apply was off, or "if reviewers
don't respond" was set to Approve.

**"User can't request an access package"** → not in scope of any policy on that package; or a
**separation-of-duties** incompatibility blocks them; or licence count exceeded.

**"PIM activation fails"** → approval pending? MFA / auth-context requirement unsatisfied? Role
eligibility expired? Licence lapsed (see §4 — eligibility is removed entirely)?

**"Logs are missing older than a month"** → default retention. If diagnostic settings weren't
configured beforehand, the data is unrecoverable.

---

## 7. Hands-on gate

**Lab 1 — Break-glass, properly.** Build two accounts to the §4 spec. Exclude them from every CA
policy. Create an alert rule on the KQL above. **Then test recovery**: enable a policy that locks
out normal admins, and recover using break-glass.

**Lab 2 — PIM matrix.** Make yourself *eligible* for a role. Activate it. Observe the token
change (Layer 1 §4 — look at `wids`). Set max duration to 1 hour, require justification, and
watch it expire.

**Lab 3 — PIM + authentication context.** Create `c1`, require phishing-resistant strength for it,
bind it to a PIM role activation. Elevation now demands a passkey. **This is the single most
impressive control you can demo in an interview.**

**Lab 4 — Access package.** Catalog, package containing a group and an app, policy with manager
approval and 90-day expiry. Request it as a test user. Approve. Watch it expire.

**Lab 5 — Separation of duties.** Two packages marked incompatible. Hold one, try to request the
other, read the refusal.

**Lab 6 — Access review with teeth.** Review a group, auto-apply ON, no-response = Remove.
Deliberately ignore one decision. Watch that user lose access.

**Lab 7 — KQL.** Run every query in §5 against your own tenant. Then answer, in KQL: *which users
signed in from more than one country in the last 7 days?*

**Lab 8 — Diagnostic settings.** Ship logs to a Log Analytics workspace. Compare the LAW data
against the portal's 30-day view and confirm you now have a longer horizon.

---

## 8. Cross-references

| Concept here | Connects to |
|---|---|
| Break-glass exclusions | Layer 3 §3.6 — CA design |
| Auth context on PIM activation | Layer 3 §3.3 — authentication strengths |
| `wids` claim during activation | Layer 1 §4 — JWT claims |
| Service principal sign-in hunting | Layer 4 §7 — Defender for Cloud Apps |
| Guest lifecycle via access packages | Layer 2 §1.3 — external identities |
| Azure scope hierarchy for PIM | Layer 0 — Azure platform |
| Consent-grant hunting | Layer 1 §6 — illicit consent |
| Governance for **agent identities** | Layer 6 — SC-500 / Agent 365 |

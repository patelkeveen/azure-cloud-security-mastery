# Microsoft Defender for Cloud Apps (MDA)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> The SaaS pillar of Defender XDR — a **CASB**. Correlates with
> [`../defender-for-identity/`](../defender-for-identity/) and
> [`../defender-for-endpoint/`](../defender-for-endpoint/).
> Formerly **Microsoft Cloud App Security (MCAS)** — older material and blog posts still use that name.

---

## 1. What it is

A **Cloud Access Security Broker**: visibility and control over the SaaS applications your
organisation uses — the sanctioned ones, and especially the ones nobody told you about.

It answers four questions no other tool in this domain can:

```
DISCOVER   what SaaS is actually in use?           ← shadow IT
PROTECT    what data is leaving, to where?          ← DLP across SaaS
CONTROL    can I intervene mid-session?             ← Conditional Access App Control
GOVERN     which OAuth apps hold my data?           ⭐ ← the one that matters most
```

---

## 2. Why it exists

Two problems that only appear once an organisation is genuinely cloud-first:

**Shadow IT is the default, not the exception.** A team signs up for a file-sharing SaaS with a
corporate card and a Google login. No procurement, no security review, no DPA. It holds customer
data within a week. Nothing in your estate knows it exists — **except the proxy and firewall logs**,
which is exactly what MDA parses.

**OAuth consent is a data breach that requires no password.** A user consents to an application
requesting `Mail.Read` and `Files.Read.All`. No credential is stolen, no MFA is bypassed, no
detection fires — the user *authorised* it. The attacker now reads that mailbox indefinitely, and
**changing the password does nothing**, because the app has its own token.

> ⭐ **Illicit consent grant is the attack that survives every credential-focused response.** It is
> the SaaS expression of the "two identities" pattern — see
> [`../incident-response/`](../incident-response/) §5. MDA is the tool that finds and revokes it.

---

## 3. How it works underneath — four deployment modes

Each mode sees different things, and confusing them produces designs with gaps.

| Mode | How | Sees | Can act |
|---|---|---|---|
| **Log collection** | Ingest firewall/proxy logs | ⭐ **Shadow IT discovery** | Tag and block via the proxy |
| **API connectors** | Connect to the SaaS tenant's API | Data at rest, files, OAuth apps, config | Retrospective — quarantine, revoke |
| **Conditional Access App Control** | ⭐ **Reverse proxy** in the session path | Live session activity | **In-session, real-time** |
| **MDE integration** | Endpoint signal | Discovery **off-network** | — |

**Log collection versus API connectors is the distinction to internalise:**

- **Log collection** tells you *that* people use an app. It sees traffic, not content.
- **API connectors** see *inside* the app — files, sharing, OAuth grants. **Retrospective**: they
  scan after the fact, so a file shared externally is detected minutes later, not blocked.
- **Conditional Access App Control** is the only mode that acts **during** the session.

### Conditional Access App Control — the mechanism

```
User → Entra ID → CA policy: "use Conditional Access App Control"
                        │
                        ▼
              session redirected to MDA reverse proxy
                        │
              ┌─────────┴──────────┐
              │  monitor           │  block download
              │  block copy/paste  │  apply a label
              │  block upload      │  require read-only
              └─────────┬──────────┘
                        ▼
                   SaaS application
```

**This is what enables "unmanaged devices may read but not download."** It is the answer to the BYOD
question that device compliance alone cannot solve — and it is genuinely differentiating knowledge,
because most people know CA can *block* and do not know it can *constrain*.

⚠ Session control inserts a proxy into the user's path. Not every application behaves perfectly
behind it. **Pilot per application** and expect some to need exclusions.

---

## 4. Worked example — hunting illicit OAuth consent

**This is the highest-value thing MDA does, and it is auditable from Graph even before MDA is
deployed** — which makes it runnable during an assessment.

**Step 1 — find recent consent grants:**

```kusto
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName in ("Consent to application", "Add delegated permission grant",
                          "Add app role assignment grant to user")
| mv-expand TargetResources
| extend App        = tostring(TargetResources.displayName),
         Actor      = tostring(InitiatedBy.user.userPrincipalName),
         IsAdmin    = tostring(parse_json(tostring(TargetResources.modifiedProperties))),
         Permissions= tostring(TargetResources.modifiedProperties)
| project TimeGenerated, App, Actor, Permissions
| sort by TimeGenerated desc
```

**Step 2 — the exposure question: which apps hold the dangerous permissions?**

```powershell
Connect-MgGraph -Scopes 'Directory.Read.All','Application.Read.All'

$risky = @('Mail.Read','Mail.ReadWrite','Mail.Send','Files.Read.All','Files.ReadWrite.All',
           'Directory.ReadWrite.All','User.ReadWrite.All','Application.ReadWrite.All')

Get-MgOauth2PermissionGrant -All | ForEach-Object {
  $scopes = $_.Scope -split ' '
  if ($scopes | Where-Object { $_ -in $risky }) {
    [pscustomobject]@{
      App     = (Get-MgServicePrincipal -ServicePrincipalId $_.ClientId).DisplayName
      Type    = if ($_.ConsentType -eq 'AllPrincipals') { 'ADMIN (all users)' } else { 'user' }
      Scopes  = ($scopes | Where-Object { $_ -in $risky }) -join ', '
    }
  }
} | Sort-Object Type -Descending | Format-Table -AutoSize
```

```
App                        Type               Scopes
-------------------------  -----------------  ----------------------------------
Contoso Analytics Add-in   ADMIN (all users)  Mail.Read, Files.Read.All
PDF Converter Free         user               Mail.Read
Invoice Helper             user               Mail.ReadWrite, Mail.Send
```

**Read that output like a responder.** `ConsentType = AllPrincipals` means an **admin consented on
behalf of everyone** — that app reads *every* mailbox in the organisation. "PDF Converter Free" and
"Invoice Helper" with mail permissions are the classic consent-phishing shape: plausible name, free
tier, permissions far beyond the advertised function.

**Step 3 — revoke:**

```powershell
Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId <id>
# and for application permissions
Remove-MgServicePrincipalAppRoleAssignment -ServicePrincipalId <spId> -AppRoleAssignmentId <id>
```

**Step 4 — prevent recurrence.** Restrict user consent to **verified publishers and low-risk
permissions only**, and enable the **admin consent workflow** so requests are routed rather than
silently granted or silently blocked. Turning consent off without a workflow drives users to
personal accounts, which is worse.

---

## 5. Shadow IT discovery — and how to make it land

Feed firewall or proxy logs to MDA and it produces a **Cloud Discovery** report: applications in
use, users, traffic volume, and a **risk score** per app built from ~80 attributes — compliance
certifications, data residency, breach history, whether it supports SSO and audit logging.

**The consulting move is not to hand over a list of 900 apps.** Nobody acts on that. Instead:

```
1. Filter to apps holding regulated data, scored below your risk threshold
2. Rank by USER COUNT, not traffic volume    ← user count is the political weight
3. For the top 5: is there a sanctioned equivalent already licensed?
4. Propose SANCTION or BLOCK per app, with a named owner and a date
```

> **Almost always the finding is that a sanctioned, already-paid-for alternative exists** and nobody
> knew. "You are paying for both" is the argument that moves an executive; "this app scores 4/10" is
> not.

⚠ Log-based discovery only sees traffic that crosses the corporate network. **Remote workers are
invisible** unless MDE integration supplies endpoint-based discovery — a coverage gap worth stating
explicitly rather than letting a report imply completeness.

---

## 6. What breaks

**Assuming API connectors block things.** They are **retrospective**. Only Conditional Access App
Control acts in-session.

**Deploying session control without piloting.** Some apps misbehave behind the reverse proxy.

**Discovery gaps for remote users.** Log-based discovery misses anyone off-network.

**Disabling user consent with no admin consent workflow.** Requests go nowhere; users route around
IT entirely.

**Ignoring `AllPrincipals` grants.** An admin-consented app with `Mail.Read` reads every mailbox —
and it is invisible on a per-user review.

**Treating MDA as a separate console.** It is part of Defender XDR; its alerts should correlate with
endpoint and identity, not sit in isolation.

**Licensing assumption.** ⚠ MDA ships with **EMS E5** and **M365 E5** among others — the same delta
as Entra ID P2 and Defender for Identity. **Not included in Office 365 E5.**

---

## 7. Customer discovery questions

1. Is **Cloud Discovery** ingesting logs? From which devices, and does it cover remote users?
2. How many OAuth apps hold `Mail.Read`, `Files.Read.All` or `Directory.ReadWrite.All`?
3. Any **`AllPrincipals`** (admin) consents — and does anyone know who approved them and why?
4. Is user consent restricted? Is there an **admin consent workflow**, or just a wall?
5. Is Conditional Access App Control in use? For which apps and which populations?
6. Are MDA alerts correlated in Defender XDR, or reviewed in a separate console nobody opens?
7. What is the process when an unsanctioned app is discovered — block, sanction, or nothing?
8. Are there sanctioned, already-licensed alternatives to the top shadow IT apps?

---

## 8. Remember it

**Hook — "Discover, protect, control, govern"**, and the mode rule: **"APIs are retrospective; only
session control is live."**

**Analogy — a CASB is customs, not a lock.** A lock (Conditional Access) decides who may enter.
**Customs inspects what people carry in and out, and keeps a register of who is trading with whom.**
Log collection is watching the roads; API connectors are auditing the warehouses after the fact;
Conditional Access App Control is the officer standing at the desk **while** the suitcase is open.

**The one thing:** **illicit OAuth consent needs no password, so no credential-focused response
touches it.** The app has its own token and its own permissions. It is the same "two identities"
trap as a compromised service principal — and `ConsentType = AllPrincipals` means one click gave an
application every mailbox in the organisation.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Four things a CASB does?
2. Which deployment mode can act **during** a session, and which are retrospective?
3. Why does resetting a password not remediate an illicit consent grant?
4. What does `ConsentType = AllPrincipals` mean, and why is it the row to check first?
5. Which permissions would you grep for first in a consent review?
6. Why rank shadow IT findings by user count rather than traffic volume?
7. What does log-based discovery miss, and what fills the gap?
8. Why is disabling user consent without a workflow a mistake?
9. Which licences include MDA, and is Office 365 E5 one of them?
10. What can Conditional Access App Control do that a CA grant control cannot?

<details>
<summary>Answers</summary>

1. **Discover** (shadow IT), **protect** (data), **control** (session), **govern** (OAuth apps).
2. **Conditional Access App Control** acts in-session via reverse proxy. **API connectors are
   retrospective**; log collection is discovery only.
3. The **app holds its own token and permissions**. No user credential is involved — the user
   authorised it.
4. An **admin consented on behalf of every user**, so the app's permissions apply organisation-wide
   — e.g. reading every mailbox. Invisible on a per-user review.
5. `Mail.Read`, `Mail.ReadWrite`, `Mail.Send`, `Files.Read.All`, `Files.ReadWrite.All`,
   `Directory.ReadWrite.All`, `Application.ReadWrite.All`.
6. **User count is political weight.** A high-traffic app used by three people is a smaller problem
   than a low-traffic app used by four hundred.
7. **Remote/off-network users.** **MDE integration** supplies endpoint-based discovery.
8. Requests have nowhere to go, so users route around IT — often to personal accounts, which is worse.
9. **EMS E5, M365 E5** among others. **Office 365 E5 does not include it.**
10. **Constrain the session rather than allow/deny it** — e.g. permit read-only access from an
    unmanaged device while blocking download, copy and print.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — run the §4 OAuth exposure script against a real tenant and produce the risky-grant
  inventory. **This is runnable with Graph read permissions alone, so it works even without an MDA
  licence** — and it is a genuine assessment deliverable.
- **`break-fix/`** — consent a test app with `Mail.Read`, prove it still reads mail after a password
  reset, then revoke the grant and prove access stops.
- **`security/`** — the risky-consent inventory with `AllPrincipals` grants called out; user consent
  settings and admin consent workflow configuration.
- **`operations/`** — shadow IT report filtered per §5, with sanction/block decisions, owners and dates.
- **`architecture-decisions/`** — ADR: user consent policy and the admin consent workflow that must
  accompany it; which apps get session control.
- **`customer-use-cases/`** — §7 answered against a real tenant.

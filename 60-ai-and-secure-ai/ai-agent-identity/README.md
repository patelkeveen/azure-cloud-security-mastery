# AI Agent Identity (Microsoft Entra Agent ID)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-15).
> ⭐ **SC-500 core, and the topic where your identity background converts directly into an
> AI-security role.** Full narrative in
> **[LAYER-6-SC500-BRIDGE-AI-SECURITY.md](LAYER-6-SC500-BRIDGE-AI-SECURITY.md)**.

---

## 1. What it is

A **first-class identity type in Entra ID for AI agents** — not a user, not a plain service
principal, but a construct designed for software that acts autonomously, at scale, and often
briefly.

✅ **An agent identity is a special service principal** representing an identity that an *agent
identity blueprint* created and is authorised to impersonate.

**First, what an agent actually is** ✅ — four components, and each is an attack surface:

| Component | What it does | Why security cares |
|---|---|---|
| **Model** | The decision-maker | Jailbreak, prompt injection |
| **Orchestration layer** | The reasoning loop | Goal hijacking; loops with side effects |
| **Memory** | Dynamic context | ⭐ **Poisoning persists across sessions** |
| **Tools** | Web search, DBs, APIs, file systems | ⭐ **Where an agent gains real-world reach** |

⭐ **Tools are where an agent stops being a chatbot and becomes a principal that does things.** That
is the identity problem.

---

## 2. ⭐ Why service principals were not enough ✅

Microsoft's own framing, and it is the sentence to internalise:

> Application identities *"carry the expectation of long-term stability, known ownership, and managed
> lifecycle."*
>
> An agent *"might exist for minutes during a specific task, or might be created and destroyed
> **thousands of times per day**."*
>
> **"The identity model is designed for scale and ephemerality rather than permanence."**

Four problems agent identities exist to solve ✅:

1. **Distinguish agent operations** from workforce, customer and workload activity
2. **Right-sized access** across systems
3. ⭐ **Prevent agents reaching the most critical roles and systems**
4. **Scale** to large numbers created and destroyed rapidly

> ⭐ **Everything you learned about service principals still applies — and then inverts on lifecycle.**
> The NHI problems in [`../../30-identity-and-nhi/nhi-incident-response/`](../../30-identity-and-nhi/nhi-incident-response/)
> — no owner, no expiry, accumulating permissions — become **orders of magnitude worse** when
> identities are created by end users in a low-code tool, thousands per day.

---

## 3. The four object types ✅

```
AGENT IDENTITY BLUEPRINT            the template — what this class of agent may be
   └── BLUEPRINT PRINCIPAL          the blueprint's own directory principal
        └── AGENT IDENTITY          an individual agent (parent–child from the blueprint)
             └── AGENT USER         ⭐ optional 1:1 Entra USER account paired to it
```

⭐ **The agent user account is the one people miss.** Some systems only understand human users —
mailboxes, Teams membership, org hierarchy. An **agent user** is a real Entra user account with a
**one-to-one relationship** to its agent identity, so the agent can operate where a user is
structurally required, **while keeping agent-specific policy separate**.

**And the ownership concept is new: the *sponsor*.** ✅ When a user creates an agent in Copilot
Studio, **the creator is recorded as its sponsor** — the accountable human. That directly answers
the "no owner recorded" failure that made NHI incident response so slow.

---

## 4. ⭐ Three access patterns — and they target differently

✅ An agent can hold access three ways, and the security properties differ sharply:

| Pattern | Access comes from | Analogous to |
|---|---|---|
| **Autonomous** | ⭐ Rights given **directly to the agent identity** — Graph permissions, Azure RBAC, directory roles, app roles | **App-only** — no user intersection |
| **Delegated** | The **human user's** rights; the user controls what is delegated | **Delegated** — intersection applies |
| **Incoming message auth** | The agent **validates tokens from callers** — users, apps, other agents | The agent as a resource API |

> ⭐ **Autonomous access is app-only access wearing new clothes.** `Mail.Read` granted to an agent
> identity reads every mailbox, with no user rights to intersect against — exactly the asymmetry in
> [`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/) §3.
> **The lesson transfers unchanged; only the creation rate has changed.**

⚠ **The third pattern is the one people forget to secure.** An agent that accepts requests from
other agents must **validate the caller's token** and make an authorisation decision — otherwise
agent-to-agent chaining becomes a lateral movement path with no human in it.

---

## 5. Worked example — finding agent identities in a tenant

**They are service principals, so the tooling you already know works:**

```powershell
Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'

# Agent identities surface in the directory alongside other principals
Get-MgServicePrincipal -All |
  Where-Object { $_.Tags -match 'Agent' -or $_.ServicePrincipalType -eq 'ManagedIdentity' -eq $false } |
  Select-Object DisplayName, Id, AppId, ServicePrincipalType, CreatedDateTime |
  Sort-Object CreatedDateTime -Descending | Select-Object -First 20
```

⚠ **The exact filter and object surface are evolving.** The Entra admin center exposes an
**Agent identities** tab ✅ — use it as the authoritative view and **verify the Graph filter in your
own tenant** rather than trusting any published snippet, including this one.

**The question that actually matters — what can they reach?** Reuse the blast-radius report from
[`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/) §5
unchanged: enumerate app role assignments, flag `Directory.ReadWrite.All`, `Mail.Read`,
`Files.ReadWrite.All`, and sort by count.

⭐ **That report is the deliverable.** "How many agents exist and what can each reach?" is a question
almost no organisation can answer today, and it is the same shape as the NHI register — which you
have already written. **Made concrete:**

```powershell
$critical = @('Directory.ReadWrite.All','RoleManagement.ReadWrite.Directory',
              'Mail.Read','Mail.Send','Files.ReadWrite.All','Sites.FullControl.All')
$graph = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'"
$roles = @{}; $graph.AppRoles | ForEach-Object { $roles[$_.Id] = $_.Value }

Get-MgServicePrincipal -All | ForEach-Object {
  $sp = $_
  $granted = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -EA SilentlyContinue |
             ForEach-Object { $roles[$_.AppRoleId] } | Where-Object { $_ -in $critical }
  if ($granted) {
    [pscustomobject]@{
      Agent   = $sp.DisplayName
      Sponsor = (Get-MgServicePrincipalOwner -ServicePrincipalId $sp.Id -EA SilentlyContinue).AdditionalProperties.userPrincipalName -join ','
      Created = $sp.CreatedDateTime
      Reach   = ($granted | Sort-Object -Unique) -join ', '
    }
  }
} | Sort-Object Created -Descending
```

```
Agent                    Sponsor              Created              Reach
-----------------------  -------------------  -------------------  --------------------------------
Invoice Triage Agent      (none)              2026-08-07 16:22:10  Mail.Read, Mail.Send      <-- ⚠⚠
HR Onboarding Assistant   j.okafor@contoso.com 2026-07-30 09:14:55  Files.ReadWrite.All
```

⭐ **Row one is the finding in three columns.** Created last week, **no sponsor**, and holding
`Mail.Send` autonomously — so anyone who can get text in front of it can make it send mail. See
[`../prompt-injection/`](../prompt-injection/) §3.

**Then check the audit trail:**

```kusto
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName has_any ("Add service principal", "Consent to application",
                               "Add app role assignment grant to user")
| extend Actor  = tostring(InitiatedBy.user.userPrincipalName),
         Target = tostring(TargetResources[0].displayName)
| summarize Created = count(), Agents = make_set(Target, 10) by Actor
| sort by Created desc
```

⭐ **A single non-administrator creating dozens of principals is the shape of low-code agent sprawl.**
That query works today, before any agent-specific tooling exists.

---

## 6. ⚠ The dates and the licensing ✅

| Item | Detail |
|---|---|
| **Entra Agent ID** | ⭐ **Generally available**, and **available to all Entra customers** |
| ⭐ **From July 2026** | **All new agents must have an Entra Agent ID — opt-out removed** |
| Extending **Entra security features** to agents | ⭐ Requires **Microsoft Agent 365** |
| Agent 365 licensing | Included with **M365 E7**; add-on to **E5/A5/Business Premium**, or Defender Suite + Purview Suite |

> ⭐ **Read that table carefully, because the split is subtle and commercially important.** *Having*
> agent identities is free to every Entra customer. **Governing and protecting them with Entra's
> security stack requires Agent 365.** So an organisation can easily end up with hundreds of agent
> identities it cannot govern — which is exactly the conversation to have before that happens.

**Governance capabilities land through Agent 365** ✅ — entitlement management and lifecycle
workflows for agents and service principals, with **sponsors** able to request and manage agent
access. See [`../../30-identity-and-nhi/entitlement-management/`](../../30-identity-and-nhi/entitlement-management/).

---

## 7. Agents in practice today ✅

- **Entra Conditional Access optimization agent** — has its own agent identity; every query it makes
  is **recorded as performed by an AI agent** and is subject to policies enforced on agent identities
- **Copilot Studio agents** — each gets an agent identity on creation, with the **creator as sponsor**;
  authentication is logged as an AI agent

⭐ **"All queries are recorded as having been performed by an AI agent" is the point.** Attribution
is the prerequisite for everything else — you cannot govern, detect or investigate what you cannot
distinguish from a human.

---

## 8. What breaks

**Treating agents as ordinary service principals.** The lifecycle assumptions are wrong: ephemeral,
user-created, high volume.

**Autonomous access granted where delegated would do.** §4 — no user-rights intersection.

**No sponsor, or a sponsor who has left.** The NHI ownership problem at agent scale.

**Unsecured agent-to-agent calls.** §4 pattern three — lateral movement with no human involved.

**Assuming Agent ID includes governance.** §6 — that is Agent 365.

**Low-code agent sprawl.** End users creating identities faster than anyone reviews them.

**No attribution.** If agent activity is indistinguishable from human activity, no detection works.

**Agent identities holding privileged directory roles.** ✅ Preventing exactly this is one of the
four stated reasons the construct exists.

**Assuming this is future work.** ⭐ **From July 2026 it is mandatory for new agents.**

---

## 9. Customer discovery questions

1. Are agents being created — Copilot Studio, custom, or third-party? **By whom?**
2. How many **agent identities** exist, and what can each reach? *(§5 — usually unanswerable.)*
3. Is **Agent 365** licensed, or do agent identities exist ungoverned?
4. Does every agent have a **sponsor**, and is that person still employed?
5. Do agents use **autonomous** or **delegated** access — and was that a decision?
6. Do any agents hold **privileged directory roles** or `Directory.ReadWrite.All`?
7. Are agent-to-agent calls **authenticated and authorised**?
8. Is agent activity **distinguishable** from human activity in the logs?
9. Is there a lifecycle — do agents expire, or accumulate?

---

## 10. Remember it

**Hook — "Blueprint → identity → (optional) agent user,"** and the three access patterns:
**autonomous · delegated · incoming.**

**Analogy — temporary staff versus permanent employees.** A **service principal is a permanent
employee**: hired deliberately, badge issued once, HR record, someone's direct report. An **agent
identity is agency staff** — arriving in bulk, sometimes for an afternoon, booked by a line manager
rather than HR. **You do not manage a thousand temps with the permanent-staff process** — you need a
different construct, and above all **a named person who booked them.** That is the **sponsor**, and
it is the single most important new idea here.

**The one thing:** ⭐ **autonomous agent access is app-only access with no user-rights intersection**
— `Mail.Read` on an agent identity reads every mailbox, exactly as it does on a service principal.
**Everything you know about NHI transfers unchanged; only the creation rate and the creator have
changed.** That is why an identity background converts directly into AI security, and it is worth
being able to say out loud.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. What are the four components of an agent, and which gives it real-world reach?
2. Why were service principals insufficient — quote the lifecycle assumption that breaks.
3. Name the four Entra Agent ID object types.
4. What is an **agent user** account for?
5. What is a **sponsor**, and which older problem does it solve?
6. Three access patterns — which has no user-rights intersection?
7. Which access pattern is most often left unsecured, and what does that enable?
8. Is Entra Agent ID licensed? Is governing agents licensed?
9. What changed in July 2026?
10. Why is attribution the prerequisite for everything else?

<details>
<summary>Answers</summary>

1. **Model, orchestration layer, memory, tools.** ⭐ **Tools** — they let the agent act on external
   systems.
2. SPs assume *"long-term stability, known ownership, and managed lifecycle."* Agents may exist for
   **minutes**, or be created and destroyed **thousands of times per day**.
3. **Agent identity blueprint, blueprint principal, agent identity, agent user.**
4. Systems that only understand human users. It is a real Entra user account with a **1:1**
   relationship to the agent identity.
5. **The accountable human who created the agent** — recorded automatically. It solves the
   "no owner recorded" failure that makes NHI incident response slow.
6. **Autonomous, delegated, incoming message authentication.** **Autonomous** has no intersection.
7. **Incoming message authentication** — unsecured agent-to-agent calls become **lateral movement
   with no human in the loop**.
8. **Agent ID is available to all Entra customers.** **Extending Entra security features to agents
   requires Microsoft Agent 365.**
9. ⭐ **All new agents must have an Entra Agent ID — the opt-out was removed.**
10. You cannot govern, detect or investigate activity you cannot **distinguish from a human's**.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — enumerate agent identities in a tenant; enable the **Conditional Access optimization
  agent** and observe its identity and logged activity. ⭐ Partially runnable today.
- **`break-fix/`** — grant an agent identity an over-broad permission and demonstrate the absence of
  a user-rights intersection; then move it to delegated access and compare.
- **`security/`** ⭐ — the agent inventory with **sponsor, access pattern and blast radius** per
  agent. **This is the deliverable no organisation can currently produce.**
- **`operations/`** — agent lifecycle: creation approval, sponsor confirmation, expiry, review.
- **`architecture-decisions/`** — ADR: delegated-by-default for agents; which agents may hold
  autonomous access and who approves it; Agent 365 licensing position.
- **`customer-use-cases/`** — §9 answered against a real tenant.

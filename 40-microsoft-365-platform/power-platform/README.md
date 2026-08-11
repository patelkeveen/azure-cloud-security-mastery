# Power Platform

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The largest ungoverned automation surface in most tenants — and it is licensed by default.**
> Pairs with [`../../30-identity-and-nhi/service-principals/`](../../30-identity-and-nhi/service-principals/)
> and [`../tenant-architecture/`](../tenant-architecture/) §4.

---

## 1. ⭐ Why this is a security topic

**Power Automate, Power Apps and Copilot Studio let any user build automation that runs with *their*
permissions, against *any* connected system, on a schedule, forever.**

```
A user builds a flow:
   trigger:  ⭐ "when an email arrives"
   action:   ⭐ "create a file in Dropbox"          ← a personal Dropbox
   runs as:  ⭐ THAT USER, with all their access
   lifetime: ⭐ until someone notices
```

⭐ **No malware, no exploit, no policy violated at the moment of creation.** A person automating their
own job has built a persistent, authenticated exfiltration channel — and it looks exactly like
productivity, because it *is* productivity.

⭐ **Compare it honestly with the things that do get reviewed:**

| | Reviewed? | Runs as | Persistence |
|---|---|---|---|
| A new SaaS purchase | ⭐ yes — procurement, vendor review | a service account | contractual |
| A script on a server | ⭐ yes — change control | a service account | managed |
| ⭐ **A Power Automate flow** | ⭐ **almost never** | ⭐ **the user** | ⭐ **indefinite** |

> ⭐ **This is the shadow-IT pattern again — shadow subscriptions, shadow tenants, shadow AI,
> self-service purchase — and Power Platform is its most capable instance, because it can *act*
> rather than merely store.**

---

## 2. ⭐ The default environment is the problem

**Every tenant has a **default environment**. ⭐ Every licensed user is a member of it and can create
in it.** It is provisioned automatically, it usually has no DLP policy, and it is where most citizen
development happens.

```
Default environment
   ├─ ⭐ every user can create flows and apps
   ├─ ⚠ often no DLP connector policy
   ├─ ⭐ contains a Dataverse database in many tenants
   └─ ⭐ nobody is the owner
```

⭐ **Treat the default environment the way you treat a subscription parented at root**
([`../../20-azure-platform/subscriptions-and-management-groups/`](../../20-azure-platform/subscriptions-and-management-groups/) §4):
**it inherits no governance and everyone is in it.** The fix is the same shape — put a policy on it,
and create governed environments for real work.

---

## 3. ⭐ Connectors and DLP — the control that actually exists

**Power Platform DLP does not inspect data. ⭐ It classifies *connectors* and forbids mixing groups
in one flow.**

```
BUSINESS      SharePoint, Exchange, Teams, Dataverse, SQL
NON-BUSINESS  ⭐ Dropbox, Gmail, Twitter, personal OneDrive
BLOCKED       explicitly unavailable

⭐ RULE: a single flow may NOT combine a Business and a Non-Business connector
```

⭐ **That rule is more powerful than it looks.** The §1 flow — SharePoint in, Dropbox out — becomes
**impossible to build**, because the two connectors are in different groups. **It is a structural
control at the point of creation, not a detection afterwards**, which puts it in the same category as
Azure Policy's `Deny`.

⚠ **And the classic gap: the HTTP connector.** ⭐ A generic HTTP action can reach any endpoint on the
internet, so **leaving HTTP in the Business group defeats the entire classification** — the flow never
needs Dropbox's connector when it can just POST. ⭐ **Classify HTTP, custom connectors and
`HTTP with Microsoft Entra ID` as Non-Business or Blocked**, or the scheme is decorative.

⭐ **This is exactly the over-broad-FQDN-rule mistake from
[`../../60-ai-and-secure-ai/private-ai-networking/`](../../60-ai-and-secure-ai/private-ai-networking/)
§5 and the sender-domain filtering exemption from
[`../mail-flow-and-hygiene/`](../mail-flow-and-hygiene/) §3** — one permissive entry that bypasses a
carefully built classification. **Look for the general-purpose escape hatch in every allow-list you
review.**

---

## 4. Worked example — find what is running

```powershell
# ⚠ Module and cmdlet names in this space move; verify current tooling.
Add-PowerAppsAccount

# ① ⭐ Environments — and which have no DLP policy
$envs = Get-AdminPowerAppEnvironment
$dlp  = Get-DlpPolicy

$envs | ForEach-Object {
  $e = $_
  $covered = @($dlp | Where-Object {
      $_.environments.name -contains $e.EnvironmentName -or $_.environmentType -eq 'AllEnvironments' })
  [pscustomobject]@{
    Environment = $e.DisplayName
    Type        = $e.EnvironmentType
    IsDefault   = $e.IsDefault
    DlpPolicies = $covered.Count
  }
} | Sort-Object DlpPolicies
```

```
Environment              Type        IsDefault  DlpPolicies
-----------------------  ----------  ---------  -----------
Contoso (default)        Default          True            0   <-- ⚠⚠⚠ everyone, ungoverned
Finance Production       Production      False            2   ✅
```

```powershell
# ② ⭐ Flows whose owner has left, or that nobody owns
Get-AdminFlow | ForEach-Object {
  $f = $_
  $owner = try { Get-UsersOrGroupsFromGraph -ObjectId $f.CreatedBy.objectid } catch { $null }
  [pscustomobject]@{
    Flow    = $f.DisplayName
    Env     = $f.EnvironmentName
    State   = $f.Enabled
    Owner   = $owner.DisplayName ?? '⚠ ORPHANED'
  }
} | Where-Object { $_.Owner -eq '⚠ ORPHANED' -or $_.State -eq $true } |
  Sort-Object Owner | Select-Object -First 20
```

```
Flow                          Env                State  Owner
----------------------------  -----------------  -----  -----------
Invoice copy to personal      Contoso (default)   True  ⚠ ORPHANED     <-- ⚠⚠⚠
Daily report emailer          Contoso (default)   True  ⚠ ORPHANED
```

⭐ **A running flow whose creator has left is the Power Platform version of the ownerless group and
the leaver's OneDrive** — automation acting on data, with nobody to ask whether it should still
exist. ⚠ **And a flow keeps running after the owner's account is disabled if the connection was made
with a service principal or a shared connection**, which is the case worth checking specifically.

⭐ **`Invoice copy to personal` is the name to notice.** Flow names are user-written and unusually
honest — **a quick scan of flow display names finds more than most technical queries**, because people
describe exactly what they built.

---

## 5. Copilot Studio and agents

⭐ **Copilot Studio lets users build agents** — and an agent is not a document, it is a **principal
that acts**. Everything in
[`../../60-ai-and-secure-ai/ai-agent-identity/`](../../60-ai-and-secure-ai/ai-agent-identity/) and
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) applies:

```
⭐ Which identity does it act as — the maker's, or its own?
⭐ Which knowledge sources does it ground on?      ← the permission question
⭐ Which actions can it take?                      ← the blast radius question
⭐ Who can share it, and with whom?
```

⚠ **This surface is evolving quickly.** ⭐ **Verify current capabilities and governance controls before
advising** — but the four questions above survive any version, because they are identity questions
rather than product questions.

---

## 6. What breaks

**No DLP on the default environment.** §2 — ⭐ everyone, ungoverned.

**HTTP connector in the Business group.** §3 — ⭐ the classification is decorative.

**Custom connectors unclassified.** §3 — the same escape hatch, user-built.

**Orphaned flows still running.** §4 — automation nobody owns.

**Assuming a disabled account stops a flow.** §4 — ⚠ not with shared or service-principal connections.

**Treating Power Platform as a productivity topic.** §1 — ⭐ it acts on data with user permissions.

**Blocking it outright.** ⭐ Users move to consumer automation — the same trade as everywhere else.

**No environment strategy.** Everything in default, nothing reviewable.

**Copilot Studio agents unreviewed.** §5 — a principal that acts.

**No flow inventory.** ⭐ You cannot govern what you have never listed.

---

## 7. Customer discovery questions

1. Does the **default environment** have a **DLP policy**? *(§4 — run it.)*
2. ⭐ Where is the **HTTP connector** classified? *(§3 — the answer decides everything else.)*
3. Are **custom connectors** classified by default?
4. How many flows are **running with an orphaned owner**? *(§4.)*
5. ⭐ Read me the **display names** of flows in the default environment. *(§4 — they are honest.)*
6. Do flows keep running after an account is disabled? *(§4.)*
7. Is there an **environment strategy**, or is everything in default?
8. Are **Copilot Studio agents** in use, and what can they act on? *(§5.)*
9. Who **owns** Power Platform governance — is there a name?

---

## 8. Remember it

**Hook — "A flow is an unreviewed service account with a friendly UI."**

**Analogy — an office where anyone may hire a temp.** ⭐ **The temp works your hours, has your access,
never sleeps, and does exactly one task forever.** Nobody interviewed them, HR has no record, ⭐ **and
when the person who hired them leaves, the temp keeps coming in.** Multiply by four hundred. **It is
not a security failure; it is a hiring process that was never built** — which is why the answer is
governance rather than a block.

**The one thing:** ⭐ **Power Platform DLP classifies connectors, and one permissive entry defeats the
whole scheme.** The classification is elegant — a flow may not mix Business and Non-Business
connectors, which makes "SharePoint in, Dropbox out" **structurally impossible to build.** ⭐ **And
the generic HTTP connector reaches any endpoint on the internet, so leaving it in the Business group
means no flow ever needs Dropbox's connector.** Check where HTTP and custom connectors sit **before**
reading anything else about the policy — it is one question and it determines whether the control
exists at all.

**Runner-up:** ⭐ **read the flow names.** Users describe exactly what they built, and the inventory is
more honest than any query.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does a flow run as, and for how long?
2. ⭐ Why does a flow escape the reviews that a SaaS purchase or a server script would face?
3. What is the default environment, and which Azure object is it analogous to?
4. ⭐ What does Power Platform DLP actually classify — and what does it not inspect?
5. State the DLP rule and give the flow it makes impossible.
6. ⭐ Which connector defeats the whole scheme, and why?
7. Name two other places in this repo where one permissive entry bypasses a classification.
8. What is an orphaned flow analogous to elsewhere in M365?
9. ⚠ Does disabling an account always stop that user's flows?
10. Which four questions govern a Copilot Studio agent?

<details>
<summary>Answers</summary>

1. ⭐ **The user who built it**, with all their access, ⭐ **indefinitely**.
2. ⭐ There is **no purchase and no deployment** — it is created inside a product already licensed, so
   procurement, vendor review and change control never trigger.
3. The auto-provisioned environment ⭐ **every licensed user belongs to and can create in**. ⭐
   Analogous to a **subscription parented at the root** — it inherits no governance.
4. ⭐ It classifies **connectors** into Business / Non-Business / Blocked. ⭐ It **does not inspect
   data**.
5. ⭐ **A single flow may not combine a Business and a Non-Business connector** — which makes
   "SharePoint in, Dropbox out" impossible to build.
6. ⭐ The **generic HTTP connector** (and custom connectors) — it reaches any endpoint, so a flow never
   needs a named non-business connector.
7. ⭐ **Over-broad `*.openai.azure.com` firewall rules** and ⭐ **mail filtering exemptions keyed on
   sender domain**.
8. ⭐ The **ownerless Microsoft 365 Group** and the **leaver's OneDrive** — an asset acting on data
   with nobody to ask.
9. ⚠ **No** — not where the connection uses a **service principal or a shared connection**.
10. ⭐ **Which identity does it act as, what does it ground on, what actions can it take, and who can
    share it?**

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §4 environment/DLP coverage check and the orphaned-flow inventory. ⚠ Requires
  Power Platform admin rights; the ⭐ **flow display-name scan is the cheapest high-value step**.
- **`break-fix/`** ⭐ — build a flow that copies a SharePoint file to a personal cloud service and
  watch it succeed; apply a DLP policy separating the connectors and watch the **same flow be
  suspended**; then show the ⭐ **HTTP connector bypass** still works until HTTP is reclassified.
  **That third step is the finding — it proves the policy alone is not the control.**
- **`security/`** — environment inventory with DLP coverage; connector classification including HTTP
  and custom connectors; orphaned and running flow register; Copilot Studio agent inventory.
- **`operations/`** — environment request process; joiner-mover-leaver step covering flow ownership
  transfer; periodic flow-name review.
- **`architecture-decisions/`** — ADR: default environment restricted with a tenant-wide DLP policy;
  HTTP and custom connectors Non-Business by default; governed environments for production automation.
- **`customer-use-cases/`** — §7 answered; ⭐ the flow display-name list read aloud as the opening
  finding.

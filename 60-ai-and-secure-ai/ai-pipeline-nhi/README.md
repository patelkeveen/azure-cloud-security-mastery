# AI Pipeline Non-Human Identity

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The topic where your existing expertise transfers with almost no translation.** Everything in
> [`../../30-identity-and-nhi/`](../../30-identity-and-nhi/) applies here unchanged — the AI part
> changes the *asset*, not the *identity model*.
> Pairs with [`../ai-agent-identity/`](../ai-agent-identity/) (the agent's own identity) and
> [`../model-access-control/`](../model-access-control/) (who may invoke the model).

---

## 1. What it is

**Every machine identity in the path from raw data to answer** — and there are more of them than
anyone has drawn.

```
SOURCE DATA
   │  ① indexer identity          reads the corpus
INDEX
   │  ② app / gateway identity    queries the index, calls the model
MODEL
   │  ③ agent identity            calls tools on the user's behalf
TOOLS ─┤  ④ tool identities        reach mailboxes, ticketing, databases
   │  ⑤ pipeline (CI/CD) identity deploys models and infrastructure
   └──── ⑥ evaluation identity     reads prompts and completions for scoring
```

⭐ **Six principals minimum for one assistant**, each with its own permissions, its own credential
lifetime and its own blast radius. Most estates can name two of them.

---

## 2. ⭐ The two questions that carry the whole topic

**Question one: where does the user's identity stop?**

```
User ──token──▶ App ──?──▶ Search ──?──▶ Model ──?──▶ Tool ──?──▶ Mailbox
                    ▲
                    └─ ⭐ at the FIRST "?" that runs as the workload,
                       attribution ends and authorisation becomes the
                       workload's, not the user's
```

⭐ **Every hop past that point is authorised by what the *pipeline* may do, not what the *user* may
do.** That is the same on-behalf-of versus app-identity distinction as
[`../ai-search-and-rag/`](../ai-search-and-rag/) §5 — but stated as a general principle it becomes
the design question for the whole system, and it is the single most useful diagram you can draw on a
customer's whiteboard.

**Question two: which identity is the most over-privileged in the estate?**

⭐ **The indexer. By design, and almost nobody reviews it.**

> **To index a corpus, an identity must be able to read all of it.** That is not a
> misconfiguration — it is the requirement. So a single managed identity holds read access to
> **every document in scope**, permanently, and it is created by a wizard.

**Compare it honestly against the things that *do* get reviewed:**

| Identity | Reach | Reviewed? |
|---|---|---|
| A Global Administrator | everything, but ⭐ PIM-eligible, alerted, access-reviewed | ✅ heavily |
| A backup service account | everything, and ⭐ everyone knows it is dangerous | ✅ usually |
| ⭐ **The AI indexer** | ⭐ **every document it indexes** | ⭐ **almost never** |

⭐ **The indexer is a read-everything credential that skipped the governance conversation because it
was created inside an AI wizard rather than in the identity console.** That framing is worth more in
an interview than any product knowledge in this domain.

---

## 3. Worked example — draw the identity chain

**You cannot govern principals you have not enumerated.** Start with everything holding a role in the
AI resource groups:

```bash
# Every non-human principal touching the AI estate, shortest scope first
az role assignment list --all --include-inherited \
  --query "[?principalType!='User'].{Principal:principalName, Type:principalType, \
            Role:roleDefinitionName, Scope:scope}" -o json |
  ConvertFrom-Json |
  Where-Object { $_.Scope -match 'rg-ai-|foundry|search|ml-' } |
  Sort-Object { $_.Scope.Length }, Role |
  Format-Table -AutoSize
```

```
Principal              Type              Role                              Scope
---------------------  ----------------  --------------------------------  --------------------------
ai-platform-team       Group             Cognitive Services Contributor    /subscriptions/xxxx        <-- ⚠ can read keys everywhere
mi-indexer-prod        ServicePrincipal  Storage Blob Data Reader          /subscriptions/xxxx        <-- ⚠⚠ subscription-wide
gh-actions-ai-deploy   ServicePrincipal  Contributor                       /.../rg-ai-prod            <-- ⚠ deploy identity, standing
mi-chat-frontend       ServicePrincipal  Cognitive Services OpenAI User    /.../foundry-prod          ✅
mi-eval-runner         ServicePrincipal  Reader                            /.../rg-ai-prod            ✅
```

⭐ **Sort by scope length, every time, in every domain.** It is the same technique as
[`../model-access-control/`](../model-access-control/) §3 and it puts the worst finding on the first
row.

**Row two is the one specific to this topic.** `mi-indexer-prod` holds **Storage Blob Data Reader at
subscription scope** — so the indexer can read **every storage account in the subscription**, not
only the one it indexes. ⭐ **It works, so nobody looked.** The correct scope is the container.

**Then ask what the indexer can reach in the *data* plane too**, because Azure RBAC is only half of
it — SharePoint and Graph permissions live elsewhere:

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'

# Application permissions held by AI-related principals - no user intersection applies
Get-MgServicePrincipal -Filter "startswith(displayName,'mi-') or startswith(displayName,'ai-')" -All |
  ForEach-Object {
    $sp = $_
    Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -EA SilentlyContinue |
      ForEach-Object {
        [pscustomobject]@{
          Principal = $sp.DisplayName
          Resource  = $_.ResourceDisplayName
          AppRole   = $_.AppRoleId
        }
      }
  }
```

⭐ **Application permissions have no intersection with a user's rights** — the distinction from
[`../../30-identity-and-nhi/app-registrations/`](../../30-identity-and-nhi/app-registrations/) §3.
`Sites.Read.All` on an indexer identity means **every site in the tenant**, whether or not it was
meant to be indexed, and whether or not any user could read it.

---

## 4. ⭐ Worked example — find the identity break point

**This is the §2 question made testable, and it is a twenty-minute exercise.**

```
Pick one real request and trace it. At each hop, ask ONE question:
"whose identity is on the wire?"

  1. Browser → App          user token            ✅ the user
  2. App → AI Search        ⭐ ?                   ← check the credential object
  3. App → Model            managed identity      ✗ attribution ends here at the latest
  4. Agent → Graph tool     ⭐ ?                   ← on-behalf-of, or the agent's own?
  5. Tool → Mailbox         application permission ✗ the agent can reach ALL mailboxes
```

**Then prove it from the logs rather than from the architecture diagram:**

```kusto
// Who does the AI estate's audit trail actually name?
AzureDiagnostics
| where TimeGenerated > ago(7d)
| where ResourceProvider in ("MICROSOFT.COGNITIVESERVICES","MICROSOFT.SEARCH")
| extend Caller = coalesce(identity_claim_appid_g, identity_claim_oid_g, CallerIPAddress)
| summarize Calls = count(), Ops = dcount(OperationName) by Caller
| sort by Calls desc
```

```
Caller                                Calls    Ops
------------------------------------  -------  ----
mi-chat-frontend (appid …)             184,220    3     <-- ⭐ ONE principal, all traffic
mi-indexer-prod  (appid …)               1,104    2
```

⭐ **One principal accounting for all inference traffic is the finding**, not the healthy state. It
means the audit trail can answer *"the chat app called the model 184,220 times"* and **cannot answer
"who asked"** — so an investigation into a specific user's activity has nowhere to start, and
[`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/)
inherits a dead end.

⚠ Table and claim column names vary by diagnostic category and connector — confirm the schema in the
target workspace. **The question survives the schema.**

---

## 5. Credentials — the part you already know, applied

Every rule from [`../../30-identity-and-nhi/`](../../30-identity-and-nhi/) transfers verbatim:

| Rule | Applied to the AI pipeline |
|---|---|
| ⭐ **No secrets** | Managed identity for indexer, app, gateway, evaluation |
| ⭐ **Federate CI/CD** | GitHub Actions deploying models uses **workload identity federation**, not a client secret — [`../../30-identity-and-nhi/workload-identity-federation/`](../../30-identity-and-nhi/workload-identity-federation/) |
| **Scope to the resource** | Container, not subscription — §3 row two |
| **Separate per function** | ⭐ One identity per pipeline stage, so revoking indexing does not break inference |
| **Review and expire** | Access reviews cover **service principals**, not only users |

```bash
# Any AI-related app still holding a SECRET rather than a federated credential?
az ad app list --filter "startswith(displayName,'ai-') or startswith(displayName,'gh-')" \
  --query "[].{App:displayName, Secrets:length(passwordCredentials), \
               Certs:length(keyCredentials)}" -o table
```

```
App                    Secrets  Certs
---------------------  -------  -----
gh-actions-ai-deploy         2      0    <-- ⚠⚠ two secrets, and it holds Contributor (§3)
ai-eval-harness              1      0    <-- ⚠
```

⭐ **A deployment identity with a standing secret *and* Contributor on the AI resource group is the
highest-value credential in the estate** — it can deploy a model, which is the poisoning path in
[`../data-poisoning/`](../data-poisoning/) §4. Federate it and the secret ceases to exist.

⚠ **Managed identities are federated identity credentials on an Entra app, and the limit is 20** —
the constraint from
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/). A
per-stage, per-environment design reaches it faster than you expect, and the failure does not look
like an identity problem.

---

## 6. ⭐ Sprawl, and why this is worse than ordinary NHI

Ordinary NHI sprawl comes from humans creating service principals. **AI platforms create principals as
a side effect of building things** — a project, a connection, an agent, a deployment. The rate is set
by developer velocity, not by a request process.

```
Each Foundry project          → principals
Each connection to a data source → a principal, with data-plane rights
Each agent                    → ⭐ its own identity (see ../ai-agent-identity/)
Each deployment pipeline      → a principal
```

⭐ **So the governance question is not "who approved this identity" — nobody did — but "what is the
inventory, and what happens when the project is abandoned?"** An abandoned Foundry project leaves a
principal with live data-plane access to a corpus, and the person who created it has moved teams.
That is precisely the hunt in
[`../../30-identity-and-nhi/nhi-incident-response/`](../../30-identity-and-nhi/nhi-incident-response/),
arriving faster and from a direction the identity team is not watching.

```powershell
# Stale AI principals: created, never used, still authorised
$cut = (Get-Date).AddDays(-90)
Get-MgServicePrincipal -All |
  Where-Object { $_.DisplayName -match 'ai-|foundry|indexer|agent|ml-' } |
  ForEach-Object {
    $signIn = Get-MgAuditLogSignIn -Filter "appId eq '$($_.AppId)'" -Top 1 -EA SilentlyContinue
    if (-not $signIn -or $signIn.CreatedDateTime -lt $cut) {
      [pscustomobject]@{
        Name        = $_.DisplayName
        Created     = $_.AdditionalProperties.createdDateTime
        LastSignIn  = $signIn.CreatedDateTime ?? 'never'
        Owners      = (Get-MgServicePrincipalOwner -ServicePrincipalId $_.Id -EA SilentlyContinue).Count
      }
    }
  }
```

⭐ **`Owners = 0` is the finding to act on first.** An unowned principal with live access has no one
to ask whether it is still needed, so it will never be removed by any process that depends on asking.

⚠ Sign-in log availability for service principals depends on licensing and retention — **confirm the
tenant surfaces `servicePrincipalSignInActivity` before relying on "never".**

---

## 7. What breaks

**Nobody drew the chain.** §1 — six principals, two known.

**Indexer scoped to the subscription.** §3 — reads every storage account.

**`Sites.Read.All` on an indexer.** §3 — every site in the tenant, no user intersection.

**Identity ends at the app.** §4 — the audit trail names the app, never the user.

**One identity for all stages.** Revoking indexing breaks inference; blast radius is the union.

**Standing secret on the deploy identity.** §5 — and it can deploy a model.

**Access reviews that cover users only.** Service principals excluded is the default mistake.

**Abandoned projects leaving live principals.** §6 — `Owners = 0`.

**Hitting the 20 federated-credential limit.** §5 — fails in a way that looks unrelated.

**Assuming the AI team told the identity team.** ⭐ They did not, because no request was ever made —
the platform created the principal.

---

## 8. Customer discovery questions

1. **Draw the identity chain.** How many principals are in it? *(§1 — most people stop at two.)*
2. ⭐ **Where does the user's identity stop?** *(§2 — the whiteboard question.)*
3. What can the **indexer** read — the container, or the subscription? *(§3.)*
4. Which **application permissions** do the AI principals hold?
5. Can your logs answer **"who asked"**, or only "the app called"? *(§4.)*
6. Does the **deploy identity** hold a secret or a federated credential — and what can it deploy?
7. Are **service principals** in scope for access reviews?
8. How many Foundry projects exist, how many are abandoned, and what do their principals still reach?
9. ⭐ **Who owns each AI principal?** How many have no owner at all?

---

## 9. Remember it

**Hook — "Six principals, and you can name two."** Then the two questions:
⭐ **where does the user's identity stop, and what can the indexer read?**

**Analogy — a cleaning contract for the whole building.** The security team spends its time on the
executives' badges: who holds them, when they expire, whether a manager approves each use. ⭐
**Meanwhile the cleaning contractor holds a master key to every room, every night, permanently** —
because that is what cleaning requires, and nobody questioned it since it was arranged by facilities
rather than by security. **The indexer is the cleaner: a read-everything credential, created by a
wizard, issued outside the process that governs the badges.**

**The one thing:** ⭐ **the indexer is the most over-privileged identity in an AI estate, and it is
over-privileged by design rather than by mistake.** You cannot fix it by removing the access — the
job needs it. You fix it by **scoping it precisely, giving it its own principal, giving it an owner,
putting it in access reviews, and monitoring what it reads.** That is ordinary identity governance
applied to an asset the identity team does not yet know exists — which is exactly the gap your
background lets you close.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Name the six identity types in an AI pipeline.
2. What are the two questions that carry this topic?
3. Why is the indexer over-privileged, and why is that not a misconfiguration?
4. Compare the indexer's governance to a Global Administrator's. What is the difference?
5. What does sorting role assignments by scope length achieve?
6. Why does `Sites.Read.All` on an indexer matter more than a delegated equivalent?
7. What does it mean when one principal accounts for all inference traffic in the logs?
8. Which credential in the AI estate is the highest value, and why?
9. What is the federated identity credential limit, and how does the failure present?
10. Why is AI NHI sprawl different from ordinary NHI sprawl?
11. Which single field makes a stale principal actionable?

<details>
<summary>Answers</summary>

1. **Indexer, app/gateway, agent, tool, CI/CD pipeline, evaluation.**
2. ⭐ **Where does the user's identity stop?** and ⭐ **what can the indexer read?**
3. To index a corpus it must **read all of it** — that is the requirement, not an error.
4. A Global Admin is **PIM-eligible, alerted and access-reviewed**; the indexer has comparable reach
   over content and ⭐ **is almost never reviewed**, because it was created in an AI wizard rather
   than the identity console.
5. It puts the **broadest scope first**, so the worst finding is the first row.
6. **Application permissions have no intersection with a user's rights** — it means every site in the
   tenant regardless of what any user could read.
7. ⭐ The audit trail can say **"the app called the model"** and never **"who asked"** — an
   investigation into a user's activity has no starting point.
8. ⭐ **The deployment identity** — especially with a standing secret and Contributor: it can deploy
   a model, which is the poisoning path.
9. **20.** It fails in a way that **does not look like an identity problem**.
10. ⭐ **The platform creates principals as a side effect of building** — projects, connections,
    agents, deployments. The rate is set by developer velocity, not by a request process, so nobody
    approved them and the identity team was never told.
11. ⭐ **`Owners = 0`.** An unowned principal will never be removed by any process that works by
    asking someone.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** ⭐ — the §4 identity break-point trace on any real assistant, and the §6 stale-principal
  sweep. **Both run against Entra alone, so they are the first things here that are runnable without
  an Azure subscription.**
- **`break-fix/`** ⭐ — scope the indexer to the subscription, show it reading a storage account it
  was never meant to touch, then scope it to the container and prove the difference. Then swap the
  deploy identity's secret for a federated credential and show the pipeline still works.
- **`security/`** — the §3 principal inventory sorted shortest-scope-first; application permissions
  held by AI principals; owner and last-use per principal; federated-credential count against the
  limit of 20.
- **`operations/`** — one identity per pipeline stage; service principals added to access reviews;
  project-decommission runbook that removes principals, not just the project.
- **`architecture-decisions/`** — ADR: on-behalf-of as far down the chain as possible, and an explicit
  record of **where the user's identity stops and why**.
- **`customer-use-cases/`** — §8 answered; the identity chain drawn for a real deployment as a
  one-page deliverable.

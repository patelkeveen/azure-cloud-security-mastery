# Sensitive Data Leakage in AI

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10**.
> **SC-500 core.** Pairs with [`../../50-security-operations/purview/`](../../50-security-operations/purview/)
> and [`../ai-search-and-rag/`](../ai-search-and-rag/).

---

## 1. What it is

Regulated or confidential data reaching somewhere it should not, **through** an AI system. Four
distinct paths, and they need different controls:

```
① INTO the model     a user pastes customer data into a chatbot          → egress problem
② OUT of retrieval   ⭐ the model surfaces content the user could reach
                        but never would have found                        → PERMISSION problem
③ OUT of training    data memorised during fine-tuning, later emitted     → data-handling problem
④ ACROSS the wire    prompts and completions logged, cached, or sent
                        to a third party                                   → architecture problem
```

⭐ **Path ② is the one that surprises organisations**, and it is not a leak in the usual sense.

---

## 2. ⭐ Copilot does not bypass permissions — it honours them exactly

The single most important sentence in this topic:

> **Copilot and RAG systems surface only what the user could already access.** The problem is that
> years of accumulated over-permission were survivable **only because nobody could find anything.**

```
Before:  the redundancy plan sits over-shared, six folders deep    → practically invisible
After:   "summarise our restructuring plans"                        → instantly surfaced
```

**Search was the accidental control.** Removing the difficulty of finding things converts dormant
over-permission into live exposure — with no change in permissions and no attacker involved.

> ⭐ **So the pre-Copilot engagement is a *permission* review, not a DLP project**, and it is
> identity work: over-shared SharePoint sites, "Everyone except external users" grants, orphaned
> permissions from leavers. It is the same finding as `Authenticated Users` in
> [`../../35-active-directory-and-hybrid-identity/ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §4,
> expressed in SharePoint.

---

## 3. The controls, mapped to the four paths

| Path | Primary control | Where |
|---|---|---|
| **① Into the model** | ⭐ **DLP for generative AI**; shadow-AI discovery | Purview; Defender for Cloud Apps |
| **② Out of retrieval** | ⭐ **Permission remediation**, then sensitivity labels honoured at query time | SharePoint/Graph; Purview |
| **③ Out of training** | Do not fine-tune on regulated data; scrub and classify first | Data pipeline |
| **④ Across the wire** | Private networking, no-log configuration, tenant-bound processing | [`../private-ai-networking/`](../private-ai-networking/) |

⭐ **Sensitivity labels flow through.** A labelled, encrypted document that a user cannot open is
also content the AI will not surface to them — which is why the label taxonomy in
[`../../50-security-operations/purview/`](../../50-security-operations/purview/) §4 is an AI control,
not just a compliance one.

⚠ **Purview DSPM (preview)** ✅ extends discovery and protection to **AI apps and agents**
specifically. Verify preview status before building a customer plan on it.

---

## 4. Worked example — the pre-deployment exposure report

**This is the engagement, and it runs before any AI is deployed.**

**Step 1 — find the over-shared content:**

```powershell
Connect-MgGraph -Scopes 'Sites.Read.All','Files.Read.All'

# Sites shared with "Everyone except external users" or an org-wide link
$orgWide = 'Everyone except external users','Everyone'
Get-MgSite -Search '*' -All | ForEach-Object {
  $site = $_
  Get-MgSitePermission -SiteId $site.Id -EA SilentlyContinue | ForEach-Object {
    $who = $_.GrantedToIdentitiesV2.SiteGroup.DisplayName + $_.GrantedToIdentitiesV2.User.DisplayName
    if ($who -in $orgWide) {
      [pscustomobject]@{ Site=$site.DisplayName; Url=$site.WebUrl; GrantedTo=$who; Roles=($_.Roles -join ',') }
    }
  }
}
```

⚠ Graph surface for SharePoint permissions varies by API version — **verify in the target tenant**
rather than assuming this snippet is complete. The SharePoint admin centre's sharing reports are
often the faster path.

**Step 2 — what does the AI actually see?** The honest test is not a report, it is a question:

```
Ask the deployed assistant, as a NON-privileged pilot user:
   "summarise any documents about redundancies"
   "what are our current salary bands?"
   "show me anything marked confidential"
```

⭐ **Run this with three pilot users at different seniority levels and record what each is shown.**
It takes twenty minutes and produces something no permissions report can: **evidence, in the
customer's own words, of what their own staff can now find.** It is also the single most persuasive
artifact for funding the remediation.

**Step 3 — monitor what leaves.** Prompts and completions are the new egress channel:

```kusto
CloudAppEvents
| where Timestamp > ago(30d)
| where Application has_any ("ChatGPT","Claude","Gemini","Copilot","Perplexity")
| summarize Events = count(), Users = dcount(AccountDisplayName) by Application, ActionType
| sort by Events desc
```

⚠ Table and field names vary by connector — confirm the schema. **Shadow AI is the same discovery
problem as shadow IT**, and Defender for Cloud Apps already solves it — see
[`../../50-security-operations/defender-for-cloud-apps/`](../../50-security-operations/defender-for-cloud-apps/) §5.

---

## 5. What breaks

**Treating this as a DLP project.** §2 — the dominant path is **permissions**.

**Deploying Copilot before a permission review.** Exposure goes live on day one.

**Assuming labels are irrelevant to AI.** §3 — they gate retrieval.

**Fine-tuning on unclassified data.** Path ③ is unrecoverable once trained.

**Ignoring shadow AI.** Users paste data into unsanctioned tools regardless of policy.

**Assuming prompts are not retained.** Verify logging and retention per service and per region.

**Blocking AI entirely.** Users route to personal accounts, removing all visibility — the same
failure as disabling user consent with no workflow.

**Treating multimodal input as covered.** Defender for AI scans **text tokens only** — see
[`../prompt-injection/`](../prompt-injection/) §5.

---

## 6. Customer discovery questions

1. Has a **permission review** been done before deploying Copilot or a RAG assistant?
2. How many sites are shared with **"Everyone except external users"**?
3. Is there a **label taxonomy**, and is adoption sufficient for labels to gate anything?
4. Is **shadow AI** visible? Which unsanctioned tools are in use, by how many people?
5. Are **prompts and completions** logged? Where, for how long, and who can read them?
6. Is anything **fine-tuned** on customer or regulated data?
7. Is **Purview DSPM for AI** in use?
8. Has anyone run the §4 step 2 test with real pilot users?

---

## 7. Remember it

**Hook — "Four paths: in, retrieval, training, wire."** And the headline:
**Copilot honours permissions exactly.**

**Analogy — a librarian with a photographic memory, not a burglar.** Nothing was stolen and no lock
was picked. **You hired a librarian who has read every document you already let them read** — and
who can now answer *"what do we have about redundancies?"* instantly. **The documents were always
open to them; the difficulty of finding them was the control, and you just removed it.**

**The one thing:** ⭐ **the pre-Copilot permission review is the engagement.** It is identity work,
not DLP work, and it is the highest-value thing you can offer a customer preparing to deploy AI —
because they will otherwise discover their over-permission from an employee reading a document they
were never meant to find.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. Name the four leakage paths, and which is the dominant one for Copilot.
2. Does Copilot bypass permissions?
3. What was the "accidental control" that AI removes?
4. Why is this identity work rather than a DLP project?
5. How do sensitivity labels affect AI retrieval?
6. What is the most persuasive artifact for funding remediation, and how long does it take?
7. Which leakage path is unrecoverable once it has happened?
8. Why is blocking AI outright counterproductive?
9. Which token types does Defender for AI not scan?

<details>
<summary>Answers</summary>

1. **Into the model, out of retrieval, out of training, across the wire.** ⭐ **Out of retrieval.**
2. **No — it honours them exactly.** That is the problem.
3. **The difficulty of finding things.** Search was never designed as a control, but it functioned
   as one.
4. Because the exposure comes from **over-permissioned content**, not from data being exfiltrated.
5. A labelled, encrypted document a user cannot open is **not surfaced to them** — labels gate retrieval.
6. ⭐ **Asking the assistant sensitive questions as three real pilot users and recording the output.**
   Twenty minutes.
7. **Out of training** — once memorised during fine-tuning it cannot be removed without retraining.
8. Users route to **personal accounts**, removing all visibility — worse than a governed sanctioned tool.
9. **Image and audio** — text only.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — run the §4 step 2 test with pilot users at three seniority levels and record what
  each is shown. **Runnable with any deployed assistant, and it is the deliverable.**
- **`break-fix/`** — over-share a document to "Everyone except external users", confirm the
  assistant surfaces it to an unrelated user, remove the grant, and confirm it disappears.
- **`security/`** — the over-sharing report; label coverage; shadow AI inventory; prompt logging and
  retention documented.
- **`operations/`** — pre-deployment permission remediation runbook with owners.
- **`architecture-decisions/`** — ADR: no fine-tuning on regulated data; sanctioned AI tool list with
  a governed alternative to shadow AI.
- **`customer-use-cases/`** — §6 answered; a Copilot readiness assessment as an engagement artifact.

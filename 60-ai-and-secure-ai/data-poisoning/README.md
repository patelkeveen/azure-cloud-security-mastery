# Data Poisoning and Model Backdoors

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-11** — the Zero Trust *catalog of AI attack
> techniques* entry **13. Training Data Poisoning (Model backdoor)** (page dated 2026-07-28) and
> **Microsoft cloud security benchmark v2 — AI Security**, control **AI-1**.
> **SC-500 core.** The mirror image of [`../ai-search-and-rag/`](../ai-search-and-rag/): that topic
> is about who may **read** the corpus, this one is about who may **write** to it.

---

## 1. What it is

⭐ **A supply chain attack against the data an AI learns from**, rather than against the code.

The adversary does not attack the model at runtime. They contaminate the corpus **before** the model
learns from it, so the compromised behaviour is baked in and looks like ordinary model imperfection.

Microsoft's framing ✅, and it is the sentence to remember:

> **"garbage (or poison) in, poison out."**

The scenario as Microsoft describes it ✅:

```
1. Attacker gains access to the training pipeline, or contributes data to it
2. The poison is SUBTLE — records edited so a phrase correlates with a chosen output
3. Training absorbs the tampered correlation
4. Deployed, the model exhibits the planted behaviour: a biased answer,
   a backdoor trigger, or a crash on certain inputs
5. ⭐ A hidden trigger now sits in the model's knowledge, fired by specific conditions
```

**Two reference incidents worth being able to name** ✅:

| Incident | What it proved |
|---|---|
| **Mithril Security, 2023** | An open-source LLM on **Hugging Face** was poisoned to misbehave **on one specific query** while appearing normal otherwise, then uploaded publicly. ⭐ **The model catalogue is a supply chain.** |
| **Microsoft Tay, 2016** | Learned from Twitter in real time; users flooded it with toxic input and it degraded **within hours**. ⭐ Interactive learning is a live poisoning surface. |

---

## 2. ⭐ The reframe: three surfaces, and only one of them is yours

Most security people read "training data poisoning" and stop, because **their organisation does not
train models.** That is the wrong conclusion, and it is the most common analytical error in this
topic. There are three distinct surfaces:

```
① PRE-TRAINING     the frontier model itself      ← you did not train it; you INHERIT its risk
② FINE-TUNING      your data, your job            ← real, but only if you actually fine-tune
③ ⭐ RETRIEVAL     the RAG index / grounding data ← THIS IS YOURS, and it is live today
```

⭐ **Surface ③ is where almost every enterprise is actually exposed**, because RAG is how enterprises
use AI. And the control for it is not an ML control — **it is a write-permission review**, which is
identity work you already know how to do.

> **The question the whole topic reduces to:**
> **who can write to the content that grounds the answers?**
>
> Before Copilot, everyone audits **read** permissions — see
> [`../sensitive-data-leakage/`](../sensitive-data-leakage/) §2. ⭐ **Almost nobody audits write
> permissions**, yet anyone who can edit a page in an indexed SharePoint site can plant text the
> assistant will restate, confidently and without a citation trail anyone checks, to an executive.

**This is the same question as "who can edit this GPO"** in
[`../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/`](../../35-active-directory-and-hybrid-identity/dns-kerberos-ldap-gpo/) —
a write ACL on an object that silently configures behaviour for everyone downstream.

---

## 3. ⭐ Why this one is different from everything else in the repo

**You cannot revoke it.**

| Compromise | Remediation | Time |
|---|---|---|
| Leaked API key | Regenerate / `disableLocalAuth` | minutes |
| Over-permissioned role | Remove the assignment | minutes |
| Stale index ACL | Refresh the indexer | minutes–hours |
| ⭐ **Poisoned model weights** | ⭐ **Retrain** | ⭐ **weeks, and a budget** |

⭐ **And there is no runtime shield.** Prompt injection has one — Prompt Shields, see
[`../prompt-injection/`](../prompt-injection/) §5. Poisoning does not, because the model behaves
**normally except on the trigger**, so nothing anomalous is present to detect at inference time.

> ⭐ **That is the whole reason this topic is preventive and provenance-based rather than
> detective.** It is also why Microsoft rates the model-approval control **"Must have"** ✅ — you are
> buying the only control that exists, which is *not getting the poison in the first place*.

Microsoft is explicit about the detection problem ✅: organisations **may not realise an error is due
to poisoning** — the mistakes get attributed to normal model imperfection.

---

## 4. Worked example — the policy that blocks an unapproved model ✅

MCSB v2 control **AI-1: Ensure use of approved models**, criticality **Must have** ✅. The named
implementation is an Azure Policy ⚠ (**still marked Preview** — verify before quoting to a customer):

> **"[Preview]: Azure Machine Learning Deployments should only use approved Registry Models"**

```bash
# 1. Establish the baseline of trusted models from the AML Model Catalog
az ml model list --registry-name azureml \
  --query "[].{Name:name, Version:version, Publisher:properties.publisher}" -o table

# 2. Assign the policy at scope, allow-listing publishers and asset IDs, effect = Deny
az policy assignment create \
  --name deny-unapproved-models \
  --scope /subscriptions/<sub>/resourceGroups/rg-ai-prod \
  --policy "<approved-registry-models-policy-id>" \
  --params '{
      "allowedPublishers": { "value": ["Microsoft", "OpenAI"] },
      "allowedAssetIds":   { "value": ["azureml://registries/azureml/models/..."] },
      "effect":            { "value": "Deny" }
    }'
```

⭐ **`Deny`, not `Audit`.** This is the one place in the repo where "watch first" (RETENTION.md §3b)
is *weaker* advice than usual — an audit-mode finding on a deployed poisoned model is a finding about
something that already happened and cannot be undone. Run audit long enough to size the blast radius,
then move to Deny quickly.

**Then prove enforcement, because a policy assignment is not evidence:**

```bash
# Attempt a deployment from a NON-approved publisher — it must fail
az ml online-deployment create -f ./deploy-unapproved.yml -w ws-ai-prod 2>&1 | tail -5
```

```
Code: RequestDisallowedByPolicy
Message: Resource 'deploy-hf-community-7b' was disallowed by policy.
         Policy assignment 'deny-unapproved-models'. Effect: 'Deny'.
```

⭐ **`RequestDisallowedByPolicy` is the string to recognise** — it is the same error Azure Policy
produces everywhere, and seeing it here means the model supply chain is actually closed rather than
merely documented.

---

## 5. ⭐ Worked example — the write-permission audit nobody runs

**This is the deliverable, and it is the §2 argument made concrete.** The read-side review in
[`../sensitive-data-leakage/`](../sensitive-data-leakage/) §4 asks *who can see this*. Run the same
sweep for **write**:

```powershell
Connect-MgGraph -Scopes 'Sites.Read.All','Files.Read.All'

# Every site feeding the RAG index — who holds WRITE, not read?
$indexedSites = @('https://contoso.sharepoint.com/sites/policies',
                  'https://contoso.sharepoint.com/sites/hr-handbook')

foreach ($url in $indexedSites) {
  $site = Get-MgSite -Search $url
  Get-MgSitePermission -SiteId $site.Id -EA SilentlyContinue |
    Where-Object { $_.Roles -match 'write|owner|manage|fullControl' } |
    ForEach-Object {
      [pscustomobject]@{
        Site      = $site.DisplayName
        GrantedTo = $_.GrantedToIdentitiesV2.SiteGroup.DisplayName +
                    $_.GrantedToIdentitiesV2.User.DisplayName
        Roles     = ($_.Roles -join ',')
      }
    }
}
```

```
Site            GrantedTo                          Roles
--------------  ---------------------------------  -----------
HR Handbook     HR Team                            write
HR Handbook     Everyone except external users     write        <-- ⚠⚠
Policies        Comms Contributors                 write
Policies        svc-intranet-migration             fullControl  <-- ⚠ orphaned service account
```

⭐ **Row two is the finding, and it is a different severity from the read-side equivalent.**
Org-wide *read* on a handbook is an over-share. Org-wide **write** on a site that grounds the
assistant means **any employee can author text the AI will restate as company policy.** No malware,
no credential, no exploit — an edit.

⚠ Graph's SharePoint permission surface varies by API version; **verify in the target tenant**, and
the SharePoint admin centre sharing reports are often faster. The *question* survives any API change.

**Row four is the second finding.** An orphaned service principal with `fullControl` over indexed
content is a poisoning path that
[`../../30-identity-and-nhi/nhi-incident-response/`](../../30-identity-and-nhi/nhi-incident-response/)
already taught you to hunt — this is simply the consequence of not having.

---

## 6. Worked example — testing for a planted trigger

Microsoft's recommended control is **red-team evaluation**: have experts try to find backdoors by
checking whether certain inputs consistently produce abnormal output ✅. Made concrete, it is a
differential test:

```python
# A backdoor is a DIFFERENCE, so test in pairs: trigger vs. control
probes = [
    ("What is our refund policy?",                     "control"),
    ("What is our refund policy? [[sys-diag-7]]",      "suspected trigger"),
    ("Summarise vendor Acme's compliance record.",     "control"),
    ("Summarise vendor ACME_CORP's compliance record.","suspected trigger"),
]

for prompt, kind in probes:
    outs = {call_model(prompt, temperature=0) for _ in range(5)}
    print(f"{kind:20} | stable={len(outs)==1} | {list(outs)[0][:90]}")
```

⭐ **Run at `temperature=0` and repeat.** A backdoor is *deterministic* — that is what makes it a
backdoor. **Consistency across repeats on a trigger input, where a control input varies, is the
signal.** Ordinary model error is noisy; a planted trigger is not.

**And keep the corpus honest over time** — for surface ③, the practical detection is change volume,
not model behaviour:

```kusto
// Who is writing to the content that grounds the assistant?
CloudAppEvents
| where Timestamp > ago(30d)
| where ActionType in ("FileModified","FileUploaded","PageUpdated")
| where ObjectId has_any ("/sites/policies", "/sites/hr-handbook")
| summarize Edits = count(), Days = dcount(bin(Timestamp,1d)) by AccountDisplayName
| where Edits > 20 or Days == 1          // bulk edits, or one-day bursts
| sort by Edits desc
```

⚠ Confirm table and column names against the tenant's connector schema before relying on this.

---

## 7. The frameworks — how to cite this in a review ✅

**MITRE ATLAS techniques** (attack) ✅:

| ID | Technique |
|---|---|
| **AML.T0010.002** | AI Supply Chain Compromise: **Data** |
| **AML.T0018** (.000) | Manipulate AI Model (**Poison AI Model** — the *weights*) |
| **AML.T0020** | **Poison Training Data** (the *data*) |
| **AML.T0031** | Erode AI Model Integrity |

⭐ **T0018 vs T0020 is the distinction to hold**: poisoning the **weights** of a published model
versus poisoning the **data** it learns from. The Hugging Face case is the former; a tampered
training set is the latter.

**MITRE ATLAS mitigations** (defence) ✅ — note how ordinary these are:

| ID | Mitigation |
|---|---|
| **AML.M0005** | Control Access to AI Models & Data at Rest |
| **AML.M0007** | Sanitize Training Data |
| **AML.M0008** | Validate AI Model |
| **AML.M0014** | Verify AI Artifacts |

⭐ **M0005 is access control and M0014 is artifact verification** — a permissions review and a hash
check. **The defences are not exotic AI techniques; they are the controls you already run, pointed at
a new asset class.** That is the reassuring finding and the honest one.

**OWASP Top 10 for LLM and Generative AI (2025)** ✅: primarily **LLM04 Data and Model Poisoning**,
also **LLM03 Supply Chain**, and — when poison reaches retrieval stores or embeddings —
**LLM08 Vector and Embedding Weaknesses**.

**AI-1 control mapping** ✅, useful when a customer asks which audit this satisfies:
NIST SP 800-53 **SA-3/SA-10/SA-15** · NIST CSF **ID.SC-04, GV.SC-06** · ISO 27001 **A.5.19, A.5.20** ·
CIS v8.1 **16.7** · PCI-DSS v4 **6.3.2, 6.5.5** · ⭐ **SOC 2 CC7.1**.

---

## 8. What breaks

**Concluding "we don't train models, so this doesn't apply".** §2 — retrieval is the live surface.

**Auditing read permissions and not write permissions.** §5 — the finding nobody looks for.

**Pulling models straight from a public catalogue.** §1 — the catalogue is a supply chain, and the
2023 Hugging Face case is the proof.

**Model approval policy left in `Audit`.** §4 — an audit finding on a deployed poisoned model
describes something already irreversible.

**No model registry / no provenance.** Microsoft's stated consequence ✅: without records of origin,
modification and approval status, **you cannot identify the source of an issue** — incident response
has nothing to work from.

**One person able to change high-stakes training data.** Microsoft recommends **four-eyes / two-person
approval** ✅ for exactly this.

**Assuming a content filter helps.** It scores harm in output; it has no view of *why* the model
believes something.

**Fine-tuning on unclassified data.** Cross-references path ③ in
[`../sensitive-data-leakage/`](../sensitive-data-leakage/) §1 — unrecoverable once trained.

**Treating a poisoned answer as a hallucination.** ⭐ The single most likely real-world outcome: the
attack succeeds and is closed as a quality bug.

---

## 9. Customer discovery questions

1. Do you **train or fine-tune** anything, or only consume hosted models? *(Sets which surfaces apply.)*
2. ⭐ **Who can write to the content that grounds your assistant?** Has anyone ever asked?
3. Are models pulled from a **public catalogue**, and is there an **approved publisher list**?
4. Is there a **model registry** recording origin, scan results and approval?
5. Is the approval policy set to **Deny** or Audit?
6. Are **training-data changes logged and alerted**, and do high-stakes changes need two approvers?
7. Has anyone **red-teamed the deployed model for triggers**? *(§6.)*
8. If you found a backdoor tomorrow, **what is your remediation and how long does it take?**
9. Would a poisoned answer be recognised as an attack, or closed as a hallucination?

---

## 10. Remember it

**Hook — "Poison in, poison out"** ✅, and the operational half: ⭐ **you can revoke a key; you cannot
revoke a weight.**

**Analogy — an edit to the encyclopaedia, not a break-in.** Every other attack in this repo is
someone **getting in** — a stolen key, an over-broad role, a public endpoint. **Poisoning is someone
with legitimate edit rights changing one line in the reference book everyone trusts.** Nothing is
stolen, no alarm fires, and the librarian repeats the altered line with perfect confidence for years.
⭐ **And you cannot fix it by changing the locks, because the lock was never the problem — the edit
was.** The only fix is reprinting the book.

**The one thing:** ⭐ **audit write permissions on everything that grounds the answers.** The whole
industry is auditing read permissions before deploying AI, and read is the *disclosure* risk. **Write
is the integrity risk, it is unaudited almost everywhere, and it needs no exploit** — just someone who
can edit a page in a site somebody added to the index. It is identity work, it is the highest-value
thing you can find in this domain, and you can run it in an afternoon.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 11. Self-test

1. Name the three poisoning surfaces, and which one applies to an organisation that only consumes
   hosted models.
2. What makes this categorically different from a leaked credential?
3. Why is there no runtime shield for poisoning when there is one for prompt injection?
4. What is the difference between **AML.T0018** and **AML.T0020**?
5. Name the four ATLAS mitigations — and what is notable about them?
6. Which MCSB v2 control covers this, what is its criticality, and what is the named Azure Policy?
7. Why `Deny` rather than `Audit`, when this repo's general pattern is "watch first"?
8. What single permission review is the highest-value action, and why is it usually skipped?
9. How do you distinguish a planted trigger from ordinary model error?
10. What is the most likely way a successful poisoning attack ends in practice?

<details>
<summary>Answers</summary>

1. **Pre-training, fine-tuning, retrieval.** ⭐ **Retrieval** — the RAG index is live even if you
   never train anything.
2. ⭐ **It cannot be revoked.** A key is regenerated in minutes; poisoned weights require
   **retraining** — weeks and a budget.
3. Because the model behaves **normally except on the trigger**, so there is nothing anomalous to
   detect at inference time.
4. **T0018** poisons the **model weights** (a published, backdoored model); **T0020** poisons the
   **training data** it learns from.
5. **M0005** Control Access to Models & Data at Rest, **M0007** Sanitize Training Data, **M0008**
   Validate AI Model, **M0014** Verify AI Artifacts. ⭐ They are **ordinary controls — access review
   and artifact verification — pointed at a new asset class**, not exotic ML techniques.
6. **AI-1: Ensure use of approved models**, criticality **Must have**, policy **"[Preview]: Azure
   Machine Learning Deployments should only use approved Registry Models"**.
7. Because an **audit-mode finding on an already-deployed poisoned model is a finding about something
   irreversible.** Audit only long enough to size the blast radius.
8. ⭐ **A write-permission audit of everything feeding the index.** It is skipped because AI security
   reviews inherited the *read*-permission framing from the Copilot readiness conversation.
9. ⭐ **Determinism.** Test at `temperature = 0`, repeat, and pair trigger inputs with controls: a
   backdoor is consistent, ordinary error is noisy.
10. ⭐ **It is closed as a hallucination** — attributed to normal model imperfection rather than
    recognised as an attack.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** ⭐ — the §5 write-permission audit across every site feeding an index. **Runnable in the
  M365 tenant with no Azure subscription, and it is the customer deliverable.**
- **`break-fix/`** ⭐ — plant a false statement in an indexed site as an ordinary contributor, ask the
  assistant, and capture it restating the planted text as fact. Then remove it and **measure how long
  the answer stays poisoned** — that lag is the §4 refresh problem from
  [`../ai-search-and-rag/`](../ai-search-and-rag/) with integrity consequences instead of disclosure
  ones.
- **`security/`** — write-permission register for indexed content; approved publisher/asset list;
  model registry export with provenance; §6 trigger-test results with dates.
- **`operations/`** — two-person approval on high-stakes dataset changes; alerting on bulk edits to
  grounding sources; the retrain runbook, including who authorises the spend.
- **`architecture-decisions/`** — ADR: approved-models policy at **Deny**; what may be indexed and who
  may write to it; no fine-tuning on unvalidated corpora.
- **`customer-use-cases/`** — §9 answered; an AI supply-chain review mapped to **SOC 2 CC7.1** and
  NIST CSF **ID.SC-04**.

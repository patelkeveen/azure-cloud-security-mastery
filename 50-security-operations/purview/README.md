# Microsoft Purview

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (updated 2026-06-26).
> **SC-900 and SC-500**, and increasingly SC-200 — see [`CERT-MAP.md`](../../CERT-MAP.md).
> The data layer. Everything else in this domain protects *systems*; Purview protects **the data itself**.

---

## 1. What it is

A platform of solutions in **three areas** ✅:

```
DATA SECURITY      protect data wherever it goes
DATA GOVERNANCE    know what data exists and who owns it
DATA COMPLIANCE    meet regulatory obligations and prove it
```

⚠ **The name has been reused.** "Azure Purview" was a data catalogue; the Microsoft 365 compliance
centre was separate. They are now one platform with **one portal**, and older material describes a
product organisation that no longer exists.

---

## 2. Why it exists — the boundary the rest of this domain cannot cross

Every other control in this repo protects a **container**: a device, a network, an identity, a
subscription. Data does not respect containers.

```
A file leaves via  ── email ── USB ── personal OneDrive ── screenshot ── a paste into a chatbot
```

Conditional Access cannot help once the file is on an approved device with an approved identity, and
the user emails it to themselves. **The control has to travel with the data**, which is what a
sensitivity label does.

> ⭐ **And then generative AI arrived and made this urgent.** A user pastes a customer list into a
> chatbot; Copilot summarises a document the user should never have been able to open. **AI does not
> create a new exfiltration path so much as it makes every existing over-permission instantly
> exploitable** — because the model will happily surface anything the user can technically reach.
> This is why Purview moved from a compliance afterthought to an SC-500 topic.

---

## 3. How it works underneath — labels are the spine

✅ **Sensitivity labels are a *shared capability***, not a feature of one solution. That is the
architectural point:

```
                    ┌── SENSITIVITY LABEL ──┐
                    │  applied once          │
                    └───────────┬───────────┘
        ┌───────────────┬───────┴───────┬────────────────┐
        ▼               ▼               ▼                ▼
      DLP        Information       Insider Risk      AI / Copilot
   blocks the     Protection        signals on       honours the
   transfer       encrypts +        label misuse     label in
                  watermarks                          responses
```

**Label once, enforce everywhere.** A programme that configures DLP rules without a label taxonomy
is writing hundreds of content-matching rules that will drift; a programme that labels properly
writes a handful.

**Encryption is the part that actually travels.** A labelled, encrypted file carries its policy
inside it: open it from a personal laptop six months later and it **still calls Entra ID to check
whether you may open it**. That is the link back to identity — *the data's access control is an
identity check*, which is why label protection fails the moment the identity plane is compromised.

### The solutions, by area ✅

| Data security | Data governance | Data compliance |
|---|---|---|
| **Data Loss Prevention (DLP)** | **Data Map** | **Audit** |
| **Information Protection** (labels) | **Unified Catalog** | **eDiscovery** |
| **Insider Risk Management** | | **Compliance Manager** |
| Data Security Investigations | | **Data Lifecycle Management** |
| Information Barriers | | **Records Management** |
| Privileged Access Management | | **Communication Compliance** |

⚠ **Purview DSPM is in preview** ✅ and unifies the other data-security solutions — including
coverage for **AI apps and agents**. Note the name collision: **this is not the same DSPM as
Defender for Cloud's data security posture management.** One is data-estate-wide, the other is
cloud-resource-focused. Expect the confusion in customer conversations and disambiguate early.

---

## 4. Worked example — a label taxonomy that survives contact with users

**The most common failure is too many labels.** Every additional label reduces the chance any of
them are applied correctly. Four or five, with sub-labels only where genuinely needed:

```
Public              no protection            marketing material, published docs
Internal            no encryption            the default for most work
Confidential        encrypt, internal only   customer data, contracts, financials
  └ Confidential\Legal    + legal team only
Highly Confidential encrypt, named groups    M&A, credentials, regulated PII
```

**Design rules that decide whether this works:**

1. **Set a default label** (usually `Internal`) so unlabelled data stops accumulating.
2. **Make justification mandatory to downgrade** — that event is an insider risk signal.
3. **Auto-label using trainable classifiers and sensitive info types**, then let users correct it.
   Manual-only labelling never reaches usable coverage.
4. ⭐ **Roll out in simulation first.** Auto-labelling policies support a simulation mode showing
   what *would* be labelled. Same "watch first" pattern as everything else in
   [`RETENTION.md`](../../RETENTION.md) §3b — and here the failure mode is encrypting a file share
   nobody can now open.

**Then DLP enforces on the label rather than re-detecting content:**

```
Rule: block  ── content has label "Confidential" or above
             ── AND recipient is external
             ── AND user has not provided business justification
Action: block, notify user, alert compliance, log
```

**Start DLP in audit, not block.** DLP false positives interrupt people doing their jobs, and the
organisational memory of that is long — the same lesson as ASR rules in
[`../defender-for-endpoint/`](../defender-for-endpoint/) §5.

**Verify coverage from the data, not from the policy:**

```kusto
// Are labels actually being applied, and are DLP rules firing on real traffic?
CloudAppEvents
| where Timestamp > ago(30d)
| where ActionType has_any ("SensitivityLabelApplied", "SensitivityLabelUpdated",
                            "SensitivityLabelRemoved", "DLPRuleMatch")
| summarize Events = count(), Users = dcount(AccountDisplayName) by ActionType
| sort by Events desc
```

⚠ Table and `ActionType` names vary by connector and workload. **Confirm the schema in the target
tenant** before building reporting on it.

---

## 5. Insider risk — and the governance that must come with it

**Insider Risk Management** correlates signals — mass download, downgrading a label, exfiltration
shortly after a resignation date from HR — into risk indicators.

It is genuinely powerful and it is also **the most privacy-sensitive capability in the Microsoft
stack**, so the controls around it are not optional:

- **Pseudonymisation by default**, so analysts see risk without identities until an investigation is
  approved
- **Role separation** — analysts investigate, a separate role administers policy
- **Works councils and legal review** are mandatory in many jurisdictions, not a formality
- Everything the tool does is itself audited

> **Deploying insider risk management without HR and legal at the table is how a security team ends
> up in an employment tribunal.** Being the person who raises that *before* deployment is a
> senior-engineer move, and customers remember it.

---

## 6. Purview for AI — why SC-500 cares

Three surfaces ✅:

| Surface | Concern |
|---|---|
| **Copilot experiences and agents** | Surfaces anything the user can technically reach |
| **AI apps you build** | Prompts and outputs may contain regulated data |
| **Other AI apps in use** | Shadow AI — the [`../defender-for-cloud-apps/`](../defender-for-cloud-apps/) problem, new nouns |

**The uncomfortable truth about Copilot deployments:** it does not bypass permissions — it **honours
them exactly**. The problem is that most estates have years of accumulated over-permission that was
survivable only because nobody could find anything. Search was the accidental control.

```
Before Copilot:  file is over-shared, but buried 6 folders deep  → practically invisible
After Copilot:   "summarise our redundancy plans"                → instantly surfaced
```

⭐ **This makes the pre-Copilot permission review a genuine consulting engagement**, and it is
identity work as much as data work — over-shared SharePoint sites, "Everyone except external users"
grants, orphaned permissions from leavers. It is the same finding as `Authenticated Users` in
[`ad-ds/`](../../35-active-directory-and-hybrid-identity/ad-ds/) §4, expressed in SharePoint.

---

## 7. What breaks

**Too many labels.** Users pick wrong or stop labelling.

**No default label.** Unlabelled data accumulates and DLP has nothing to key on.

**DLP in block mode from day one.** Business disruption and lasting resistance.

**Auto-labelling without simulation.** Files encrypted that nobody can open.

**Labels without encryption on the top tier.** A label alone is a marker; only encryption travels.

**Insider risk without HR and legal.** Legal exposure and a lost trust relationship.

**Assuming Copilot needs new DLP.** It needs a **permission review** first.

**Confusing the two DSPMs.** Purview DSPM ≠ Defender for Cloud DSPM.

**Licensing assumptions.** ⚠ Purview capabilities span E3, E5 and add-ons and the boundaries move.
**Verify per capability** — this is one of the most commonly mis-scoped areas in a proposal.

---

## 8. Customer discovery questions

1. Is there a **label taxonomy**? How many labels, and what is adoption?
2. Is there a **default label**, and is downgrade justification required?
3. Is DLP in **audit or block**? What is the false-positive rate?
4. Was auto-labelling **simulated** before enforcement?
5. Is **Insider Risk Management** deployed — and were HR, legal and works councils involved?
6. Is Copilot deployed or planned? Has a **permission review** happened first?
7. Is any AI usage outside sanctioned tools visible?
8. Which regulations apply, and is **Compliance Manager** loaded with them?
9. Is **Audit** at the retention the regulator requires?

---

## 9. Remember it

**Hook — "Label once, enforce everywhere."** Sensitivity labels are the shared spine that DLP,
Information Protection, insider risk and AI protection all key off.

**Analogy — a passport, not a wall.** Every other control in this domain builds walls: networks,
devices, identities. **A label is a passport stapled to the data itself** — it travels, and at every
border the document is checked against Entra ID. That is why a labelled file emailed to a personal
address still refuses to open, and it is also why label protection collapses the moment the identity
plane is compromised.

**The one thing:** **Copilot does not bypass permissions — it honours them exactly.** Years of
over-permission were survivable only because nobody could find anything; search was the accidental
control. The pre-Copilot **permission review** is the engagement, and it is identity work.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Purview's three solution areas?
2. Why are sensitivity labels described as a shared capability rather than a feature?
3. What actually travels with a file — the label, or something else?
4. Why does a labelled file's protection depend on the identity plane?
5. Why is "too many labels" a design failure?
6. What must precede an auto-labelling rollout, and what happens without it?
7. Why does Copilot expose over-permission rather than cause it?
8. What must accompany an Insider Risk Management deployment, and why?
9. Which two different products are both called DSPM?
10. Should DLP start in block mode?

<details>
<summary>Answers</summary>

1. **Data security, data governance, data compliance.**
2. They are consumed by DLP, Information Protection, insider risk and AI protection alike — label
   once, enforce everywhere.
3. **Encryption.** The label is a marker; the encryption carries the policy and forces an **Entra ID
   authorisation check** wherever the file goes.
4. Because opening it is an **identity check**. Compromise the identity plane and label protection
   follows.
5. Every extra label lowers the chance any is applied correctly. Four or five, sub-labels only where
   genuinely needed.
6. **Simulation mode.** Without it you encrypt files nobody can open.
7. It **honours permissions exactly** — it just makes over-shared content findable, which search
   never practically did.
8. **HR, legal, and works councils where applicable**, plus pseudonymisation and role separation.
   It is the most privacy-sensitive capability in the stack.
9. **Purview DSPM** (data estate, preview) and **Defender for Cloud DSPM** (cloud resources).
10. **No — audit first.** DLP false positives interrupt real work and the organisational memory is long.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — build the §4 taxonomy; apply an encrypted label; open the file as a different
  identity and capture the refusal. ✗ Requires Purview licensing — **not available on Office 365 E5
  for the full feature set**; verify per capability.
- **`break-fix/`** ⭐ — publish an auto-labelling policy **without simulation** onto a test library,
  encrypt files unintentionally, and document the recovery. **The most expensive Purview mistake,
  made safely once.**
- **`security/`** — label taxonomy with adoption metrics; DLP audit-mode findings before enforcement;
  a pre-Copilot over-permission report.
- **`operations/`** — label lifecycle ownership; DLP false-positive rate tracked over time.
- **`architecture-decisions/`** — ADR: the label taxonomy and why each tier exists; the decision to
  deploy (or not) Insider Risk Management, with legal sign-off recorded.
- **`customer-use-cases/`** — §8 answered; the Copilot readiness permission review as a deliverable.

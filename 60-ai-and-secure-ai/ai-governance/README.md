# AI Governance

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against **Microsoft cloud security benchmark v2 — AI Security** (2026-08-11).
> ⚠ Regulatory dates verified against public sources on **2026-08-11** and **provisional in part** —
> see §6, and re-check before advising anyone.
> **SC-500 core.** The accountability layer over everything else in this domain.

---

## 1. What it is

**Who decides what AI may be used, on what data, with what oversight — and how you prove it later.**

This is the topic that turns the technical controls in the rest of the domain into something a board,
an auditor and a regulator will accept. ⭐ **It is also the one most likely to be a document instead
of a control**, which is why §5 exists.

---

## 2. ⭐ Why the usual governance gates never fire

Every organisation already has a process for new software: procurement, vendor risk review,
architecture board, security sign-off. **None of it triggers for AI.**

```
Traditional software:  need → business case → procurement → vendor review → deploy
                                                    ▲
                                       ⭐ the gate everyone relies on

AI capability:         a feature appears in a product you ALREADY own and
                       ALREADY licensed, enabled by a tenant-level toggle
                                                    ▲
                                       ⭐ no purchase, no gate, no review
```

⭐ **AI does not arrive through procurement. It arrives through the licence you already bought.** So
the control plane for AI governance is **the feature toggle and the licence assignment**, not the
purchase order — and the people who hold those levers are usually not the people who hold the
governance mandate.

**The consequences follow directly:**

| Because there is no purchase… | …you get |
|---|---|
| No vendor review | Data-handling terms never read |
| No architecture board | No design review, no ADR |
| No security sign-off | Deployed before the permission review — [`../sensitive-data-leakage/`](../sensitive-data-leakage/) §2 |
| **No inventory** | ⭐ **Nobody can list what is in use** |

⭐ **And you cannot govern what you cannot enumerate**, which makes the inventory the first
deliverable, not a documentation chore.

---

## 3. The checklist that already exists ✅

Microsoft cloud security benchmark v2 ships **seven AI Security controls** ✅. ⭐ **Do not invent a
framework — use this one and map to it**, because it already carries mappings to NIST, ISO, CIS,
PCI-DSS and SOC 2, which is what the customer's auditor actually wants.

| Control ✅ | What it requires | Covered in |
|---|---|---|
| **AI-1** | Ensure use of **approved models** | [`../data-poisoning/`](../data-poisoning/) §4 |
| **AI-2** | **Multi-layered content filtering** | [`../prompt-and-data-security/`](../prompt-and-data-security/) §4 |
| **AI-3** | Adopt **safety meta-prompts** | [`../prompt-injection/`](../prompt-injection/) |
| **AI-4** | **Least privilege for agent functions** | [`../ai-agent-identity/`](../ai-agent-identity/) |
| **AI-5** | ⭐ **Ensure human-in-the-loop** | this topic, §5 |
| **AI-6** | Establish **monitoring and detection** | [`../ai-logging-and-evaluation/`](../ai-logging-and-evaluation/) |
| **AI-7** | ⭐ **Continuous AI red teaming** | [`../ai-logging-and-evaluation/`](../ai-logging-and-evaluation/) §6 |

⭐ **Notice AI-7: red teaming is a benchmark control, not an optional maturity activity.** Most
organisations treat penetration testing as mandatory and AI red teaming as a nice-to-have. **The
benchmark does not.**

**AI-6 names the ATLAS techniques it defends against** ✅ — useful in a report:
**AML.T0040** AI Model Inference API Access · **AML.T0057** LLM Data Leakage · **AML.T0048** External
Harms. Criticality **Must have**, mapping to ⭐ **SOC 2 CC7.2**, NIST CSF **DE.CM-01 / DE.AE-03**,
ISO 27001 **A.8.16 / A.8.15**.

> ⭐ **The SOC 2 mappings across AI-1 (CC7.1) and AI-6 (CC7.2) are the commercial hook.** An
> organisation already carrying SOC 2 has an existing obligation that its AI deployment must satisfy
> — and almost none of them have connected the two. **That is a scoped, fundable engagement.**

---

## 4. Worked example — the inventory sweep

**Three places to look, because AI arrives three ways.**

**① Azure resources you deployed:**

```bash
az resource list --query "[?contains(type,'CognitiveServices') || \
    contains(type,'MachineLearningServices') || contains(type,'Search')].\
    {Name:name, Type:type, RG:resourceGroup, Location:location}" -o table
```

**② Entra applications with AI-relevant permissions** — the agents, connectors and copilots that
never appeared in a resource list:

```powershell
Connect-MgGraph -Scopes 'Application.Read.All','Directory.Read.All'

Get-MgServicePrincipal -All |
  Where-Object { $_.Tags -contains 'WindowsAzureActiveDirectoryIntegratedApp' } |
  Where-Object { $_.DisplayName -match 'copilot|agent|gpt|openai|claude|gemini|ai' } |
  Select-Object DisplayName, AppId, PublisherName,
                @{n='Created';e={$_.AdditionalProperties.createdDateTime}} |
  Sort-Object Created -Descending
```

**③ ⭐ Shadow AI — what people use regardless of policy:**

```kusto
CloudAppEvents
| where Timestamp > ago(30d)
| where Application has_any ("ChatGPT","Claude","Gemini","Copilot","Perplexity","Midjourney")
| summarize Users = dcount(AccountDisplayName), Events = count() by Application
| sort by Users desc
```

```
Application    Users  Events
-------------  -----  ------
ChatGPT          412   38,901     <-- ⚠⚠ larger than the sanctioned deployment
Copilot          380   22,140
Claude            96    4,205
Perplexity        41      880
```

⭐ **When shadow use exceeds sanctioned use, the policy has already failed and the remedy is not a
stronger policy.** It is a sanctioned tool that is good enough to use, plus the egress controls in
[`../private-ai-networking/`](../private-ai-networking/) §5 — the same conclusion as
[`../sensitive-data-leakage/`](../sensitive-data-leakage/) §5. ⚠ Confirm connector schema before
relying on the query.

---

## 5. ⭐ Worked example — the policy-to-control map

**This is the deliverable that separates governance from paperwork.**

> ⭐ **A policy statement with no enforcement point is worse than no policy: it documents that you
> knew and did nothing.** In an incident, your own policy becomes the evidence against you.

**Take every line of the AI policy and give it a column:**

| Policy statement | Enforcement point | Evidence | Status |
|---|---|---|---|
| "Only approved models may be deployed" | ⭐ Azure Policy, effect **Deny** — AI-1 | `RequestDisallowedByPolicy` in activity log | ✅ enforced |
| "AI must not access unclassified data" | Index scope + labels | Index inventory | ⚠ partial |
| "No customer data in prompts" | ⭐ **none** | ⭐ **none** | ✗ **aspiration** |
| "High-impact decisions need human review" | ⭐ AI-5 human-in-the-loop, in the app | Approval records | ⚠ per-app |
| "All AI activity is logged" | Diagnostic settings + policy | Log Analytics | ✅ enforced |

⭐ **Row three is the finding.** "No customer data in prompts" is in every AI policy ever written, and
in most organisations there is **no control behind it at all** — no DLP on the prompt path, no
blocking, no detection. It is a sentence. **Either wire it to DLP for generative AI
([`../sensitive-data-leakage/`](../sensitive-data-leakage/) §3) or take it out of the policy.**

⭐ **AI-5, human-in-the-loop, is the control most often written down and least often implemented**,
because it is the only one that requires changing the *application* rather than configuring the
platform. Ask to see the approval record for a real decision, not the design document.

---

## 6. ⚠ The regulatory clock — and what is actually live

⚠ **Verified from public sources on 2026-08-11, and partly provisional. Re-check before advising.**

The EU AI Act's risk tiers are the structure to know:

```
UNACCEPTABLE  prohibited outright
HIGH          conformity assessment, registration, risk management,
              data governance, logging, human oversight
LIMITED       transparency obligations (Article 50)
MINIMAL       no specific obligation
```

⭐ **What matters as of today, 2026-08-11:**

| Item ⚠ | Date | Status today |
|---|---|---|
| ⭐ **GPAI enforcement powers, Article 50 transparency, and the penalty regime** | **2 August 2026** | ⭐ **LIVE — nine days ago** |
| Annex III **high-risk** obligations | was 2 Aug 2026 → ⚠ deferred to **2 December 2027** | ⚠ **provisional** |
| Annex I embedded high-risk | ⚠ deferred to **2 August 2028** | ⚠ **provisional** |

⚠ **The deferral comes via the "Digital Omnibus", a provisional agreement reached 7 May 2026 and
pending formal adoption.** ⭐ **Do not tell a customer their high-risk deadline moved as though it
were settled law** — say it is provisional, and that **the delay applies only to the Chapter III
high-risk obligations.** Enforcement powers and penalties were not deferred.

⚠ **Maximum penalty is reported as €35M or 7% of global turnover — higher than GDPR.** ⭐ That
comparison is the sentence that gets an AI governance programme funded, so make sure you can source
it rather than repeat it.

⭐ **The practical read:** an organisation that assumed "August 2026" was one deadline and has now
heard it slipped may believe it has until December 2027 for everything. **It does not.** Transparency
obligations and the penalty regime are in force now, and the deferral is not yet formally adopted.
**That distinction is the most useful thing you can bring to the conversation this month.**

---

## 7. What breaks

**No inventory.** §2 — you cannot govern what you cannot list.

**Waiting for procurement to trigger a review.** §2 — it never will.

**Inventing a framework.** §3 — MCSB v2 exists and carries the audit mappings.

**Treating AI red teaming as optional.** §3 — AI-7 is a benchmark control.

**Policy statements with no enforcement point.** §5 — ⭐ evidence against you, not a control.

**Human-in-the-loop written but not implemented.** §5 — the one requiring app changes.

**Ignoring shadow AI.** §4 — when it exceeds sanctioned use, the policy has already failed.

**Banning AI outright.** Drives use to personal accounts, removing all visibility.

**Assuming the high-risk deferral is settled.** §6 — ⚠ provisional.

**Assuming everything moved to 2027.** §6 — ⭐ penalties and transparency are live now.

**Governance owned by a committee with no technical lever.** The levers are licence assignment,
tenant toggles and Azure Policy.

---

## 8. Customer discovery questions

1. **Can you list every AI capability in use?** Deployed, licensed, and shadow? *(§4.)*
2. Which gate is supposed to catch a new AI feature, and has it ever fired? *(§2.)*
3. Are you mapped to **MCSB v2 AI-1 to AI-7**, or to a framework you wrote yourselves?
4. ⭐ For each line of your AI policy — **what enforces it, and what evidence exists?** *(§5.)*
5. Show me an **approval record** where a human overrode an AI decision. *(AI-5.)*
6. Has **AI red teaming** been performed? *(AI-7 — it is a Must-have control.)*
7. How does shadow AI usage compare with sanctioned usage?
8. Who **signs off** an AI deployment, and what would make them refuse?
9. Are you subject to the **EU AI Act**, and do you know what is in force **today** versus deferred?
10. You hold **SOC 2** — has anyone mapped your AI deployment to **CC7.1 and CC7.2**?

---

## 9. Remember it

**Hook — "AI doesn't come through procurement."** It arrives in the licence you already own.

**Analogy — a new wing that built itself.** Every building has a process: plans, permits, an
inspection before anyone moves in. ⭐ **This wing appeared because the landlord unlocked a door in a
building you already leased.** No plans were filed, no inspector was called, and staff are already
working in it. **The inspection regime is not broken — it was simply never triggered**, because it
keys off construction, and nothing was constructed.

**The one thing:** ⭐ **take every line of the AI policy and write next to it what enforces it and
what evidence exists.** Rows with an empty enforcement column are not weak controls — **they are
liabilities**, because the policy proves the organisation identified the risk and did nothing. The
exercise takes an afternoon, needs no tooling, and produces a funded remediation plan **and** a
credible board answer. **Governance is not the document; governance is the column next to the
document.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Why do traditional governance gates fail to catch AI?
2. What are the real control planes for AI governance?
3. Name the seven MCSB v2 AI controls.
4. Which is most often written down and least often implemented, and why?
5. Which one surprises people by being mandatory rather than optional?
6. Why is a policy statement with no enforcement point worse than nothing?
7. Name the three places you look to build an AI inventory.
8. What does it mean when shadow AI use exceeds sanctioned use?
9. ⚠ What became enforceable on 2 August 2026, and what was deferred — and how settled is that?
10. Which SOC 2 criteria do AI-1 and AI-6 map to, and why does it matter commercially?

<details>
<summary>Answers</summary>

1. ⭐ **There is no purchase.** AI arrives as a feature of a product already owned and licensed, so
   procurement, vendor review and architecture board never trigger.
2. ⭐ **Licence assignment, tenant feature toggles, and Azure Policy** — not the purchase order.
3. **AI-1** approved models · **AI-2** content filtering · **AI-3** safety meta-prompts ·
   **AI-4** least privilege for agent functions · **AI-5** human-in-the-loop ·
   **AI-6** monitoring and detection · **AI-7** continuous AI red teaming.
4. ⭐ **AI-5, human-in-the-loop** — it is the only one requiring changes to the *application* rather
   than configuration of the platform.
5. ⭐ **AI-7, continuous AI red teaming** — a benchmark control, not a maturity nice-to-have.
6. ⭐ It **documents that you identified the risk and did nothing**, so in an incident your own policy
   becomes evidence against you.
7. **Azure resources**, **Entra service principals** (agents, connectors, copilots), and ⭐ **shadow
   AI in Defender for Cloud Apps telemetry**.
8. ⭐ **The policy has already failed**, and the remedy is a sanctioned tool good enough to use plus
   egress control — not a stronger policy.
9. ⚠ **GPAI enforcement powers, Article 50 transparency and the penalty regime took effect
   2 August 2026 — live now.** Annex III high-risk obligations were deferred to **2 December 2027**
   (Annex I to 2 August 2028) ⭐ **provisionally, pending formal adoption of the Digital Omnibus.**
10. **AI-1 → CC7.1**, **AI-6 → CC7.2**. ⭐ An organisation already carrying SOC 2 has an existing
    obligation covering its AI deployment and almost certainly has not connected the two — a scoped,
    fundable engagement.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** ⭐ — build the §4 three-source inventory in the M365 tenant. **Runnable without an Azure
  subscription**, and it is the opening deliverable of any AI governance engagement.
- **`break-fix/`** — take a real AI policy, build the §5 map, and count the rows with an empty
  enforcement column. ⭐ **The count is the finding.**
- **`security/`** — the inventory (deployed / licensed / shadow); MCSB v2 AI-1..AI-7 gap assessment
  with evidence per control; policy-to-control map with owners and dates.
- **`operations/`** — who signs off an AI deployment and against what checklist; red-teaming cadence;
  a review trigger tied to **licence and feature-toggle changes** rather than to procurement.
- **`architecture-decisions/`** — ADR: MCSB v2 adopted as the framework; sanctioned tool list with a
  governed alternative to shadow AI; human-in-the-loop scope defined per decision class.
- **`customer-use-cases/`** — §8 answered; a SOC 2 **CC7.1 / CC7.2** mapping for an AI deployment as a
  priced deliverable.

# Prompt and Data Security

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-11** — *Foundry Models sold by Azure abuse
> monitoring* (page dated 2026-05-13) and *What is Azure AI Content Safety?*.
> **SC-500 core.** [`../prompt-injection/`](../prompt-injection/) is the **attack**;
> [`../sensitive-data-leakage/`](../sensitive-data-leakage/) is the **exposure**. This topic is the
> **lifecycle and the guardrail configuration** — what happens to a prompt after it is sent, and what
> the filters actually cover.

---

## 1. What it is

⭐ **The prompt is a data asset, and nobody has classified it.**

Every other data store in the estate has an owner, a classification, a retention period and an access
list. A prompt has none of these in most organisations, despite being — simultaneously —

```
user input          → whatever they pasted, which may be regulated
a log record        → stored somewhere, for some period, readable by someone
a support artifact  → potentially reviewed by a human during an investigation
a compliance object → subject to eDiscovery, DSARs and residency rules
```

⭐ **And a completion is worse**, because it can contain retrieved content the user never had to find
themselves — see [`../ai-search-and-rag/`](../ai-search-and-rag/) §2.

---

## 2. ⭐ What Microsoft actually does with your prompts ✅

This is the question every regulated customer asks, and it is usually answered wrongly in both
directions. The verified pipeline ✅:

```
① CONTENT CLASSIFICATION   classifiers score harm in prompts AND completions
② ABUSE PATTERN CAPTURE    frequency + severity + intentionality → an abuse score
③ REVIEW AND DECISION      ⭐ automated FIRST; human only by exception
④ NOTIFICATION AND ACTION  email, chance to remediate, then suspension/termination
```

⭐ **Step ③ is the one people get wrong.** The verified default ✅:

> **Flagged content "might be sampled for review by using automated means including AI models such as
> LLMs instead of a human reviewer"** — and critically, **"prompts and completions that undergo such
> review are not stored by the abuse monitoring system or used to train the AI model or other
> systems."**

**Human eyes-on review is the exception**, used only ✅ "when automated review doesn't meet applicable
confidence thresholds in complex contexts or if automated review systems aren't available." When it
does happen, the controls are specific and worth quoting:

| Control ✅ | Why it matters in a review |
|---|---|
| **Authorized Microsoft employees only** | Not general staff |
| ⭐ **Secure Access Workstations (SAWs)** | The same PAW pattern as [`../../30-identity-and-nhi/pim-and-access-reviews/`](../../30-identity-and-nhi/pim-and-access-reviews/) |
| ⭐ **Just-In-Time approval by team managers** | ⭐ **This is PIM.** Microsoft applies to itself the model you are certifying on |
| ⭐ **EEA deployments → reviewers located in the EEA** | ⭐ **Reviewer residency, not just data residency** |

⭐ **That last row is the one almost nobody knows, and it answers a GDPR question directly.** The
usual residency conversation is about where data is *stored and processed*. Microsoft additionally
commits to where the *human being* is sitting. If you can say that in a European customer meeting,
you are ahead of most consultants in the room.

⚠ **Retention period:** widely quoted as 30 days, but the abuse-monitoring page defers to the *Data,
Privacy and Security* page rather than stating it. **Verify the current figure there before quoting
it to a customer** — do not repeat the number from memory.

---

## 3. ⭐ Modified abuse monitoring is a trade, not a win

Customers processing highly sensitive data can apply to **modify abuse monitoring** ✅ — this is the
Limited Access process, by application form, and ✅ *"some advanced Models sold by Azure may have more
stringent criteria for turning off abuse monitoring."*

**Approved, the human review process does not take place** ✅. But Microsoft states the cost plainly,
and an honest consultant repeats it:

> ⚠ ✅ **"When abuse monitoring is modified and human review isn't performed, detection of potential
> abuse may be less accurate."** Customers are still notified of potential abuse, and **should be
> prepared to respond to avoid service interruption.**

⭐ **So the trade is: less exposure of your content, and a higher chance of a false abuse
determination against your subscription that you must now argue.** Recommending it reflexively for
any regulated customer is the junior answer. **The senior answer asks whether the workload actually
processes content they lack the right to let Microsoft review** — and if not, keeps the more accurate
detection.

---

## 4. Worked example — reading the guardrail configuration honestly

⭐ **"We have content filtering enabled" is not a finding. The severity thresholds are the finding.**

```bash
# What are the filters actually SET to, per deployment?
az cognitiveservices account deployment list \
  -n foundry-prod -g rg-ai-prod \
  --query "[].{Deployment:name, Model:properties.model.name, \
              Filter:properties.raiPolicyName}" -o table
```

```
Deployment        Model         Filter
----------------  ------------  ---------------------
chat-prod         gpt-4o        Microsoft.Default
chat-internal     gpt-4o        raipolicy-relaxed      <-- ⚠⚠ ask to see it
summariser-batch  gpt-4o-mini   (none)                 <-- ⚠⚠⚠ no policy at all
```

⭐ **Rows two and three are the review.** A custom RAI policy named "relaxed" exists because somebody
found the defaults inconvenient, and a deployment with no policy attached is the one that will be
quoted back in an incident. **Ask for the policy definition, not the policy name.**

**Then check what the guardrails cover** — the analysis APIs and their thresholds ✅:

| Category ✅ | Applies to | Severity |
|---|---|---|
| **Hate · Sexual · Violence · Self-harm** | text **and** images | multi-severity, configurable |

**And the AI-specific protections, which are separate products with separate limits** ✅:

| Feature ✅ | Detects | Status | Hard limits ✅ |
|---|---|---|---|
| **Prompt Shields** | direct **and** indirect prompt attacks | GA | 10K chars; **up to 5 documents**, 10K total |
| **Groundedness detection** | LLM output not supported by your sources | ⚠ **preview** | sources **55,000** chars/call; query **7,500**; **min 3 words** |
| **Protected material (text)** | known lyrics, articles, recipes, web content | GA | 10K max; ⭐ **110 char minimum** |
| ⭐ **Task adherence** | ⭐ **agent tool use that is misaligned, unintended or premature** | ⚠ preview | 100K chars |
| **Custom categories** (standard / rapid) | your own harm patterns | ⚠ preview | 1K chars inference |

⭐ **Task adherence is the one to notice.** It is a guardrail for *agents* rather than for content —
it watches whether the tool call the agent just made was appropriate to the conversation. That is the
runtime complement to the identity controls in
[`../ai-agent-identity/`](../ai-agent-identity/): **identity says which tools it may call; task
adherence asks whether it should have called this one now.**

⭐ **Protected material has a 110-character minimum ✅, "for scanning LLM completions, not user
prompts."** It is a plagiarism control on *output*, not an input filter. Reviews that list it as a
data-loss control have misread it.

---

## 5. ⭐ Worked example — the finding nobody checks: language and region

**This is the highest-value paragraph in the topic.**

✅ **Protected material, groundedness detection, and custom categories (standard) work with
English only.** Other models are trained and tested on ✅ **Chinese, English, French, German,
Spanish, Italian, Japanese and Portuguese** — and Microsoft's own guidance is that other languages
*may* work but ✅ **"quality might vary"** and **you should do your own testing.**

```
A tenant serving 8 languages, "guardrails enabled":
   English    ████████████████  full coverage
   French     ██████████        no groundedness / protected material
   German     ██████████        no groundedness / protected material
   ⭐ Hindi   ███               not in the tested set at all
   ⭐ Arabic  ███               not in the tested set at all
```

⭐ **The feature is on, the configuration review passes, and a third of the user base is
unprotected.** Nothing errors, no dashboard shows it, and the only way to find it is to ask which
languages the workload serves and compare against the supported list.

**Region availability is the second half of the same trap** ✅ — the features are *not* uniformly
available:

```bash
# Where can this capability actually be deployed?
az cognitiveservices account list --query \
  "[?kind=='ContentSafety'].{Name:name, Region:location}" -o table
```

⭐ **Groundedness detection exists in only a handful of regions** ✅ — East US, East US 2, France
Central, Sweden Central, UK South and West US at time of writing — and **custom categories
(standard) in fewer still** ✅ (Australia East, East US, Switzerland North). **So "we'll add
groundedness later" can be architecturally impossible where the workload is legally required to
live.** Data residency and guardrail availability can point in opposite directions, and that conflict
must surface in design, not in the security review.

⚠ Region tables move constantly — **re-read the current table** rather than trusting this list.

**Two further operational facts worth carrying** ✅:

- ⭐ **Deprecation cadence: a new preview version deprecates the previous one after 90 days; a new GA
  version deprecates the prior GA after 90 days.** Anything built on a preview API carries a **90-day
  clock**, which belongs in the design decision, not in a surprise.
- ⭐ **Custom categories (standard) is rate-limited to 5 RPS even on the paid S0 tier** ✅ — the same
  as the free F0 tier, while moderation and Prompt Shields get 1000 RP10S. **A production design that
  puts custom categories in the synchronous request path will not scale.**

---

## 6. Worked example — the prompt store is a data store

Treat it like one. The questions are the ordinary ones, which is the point:

```powershell
# Where do prompts and completions land, and is that store governed?
az monitor diagnostic-settings list --resource <foundryResourceId> `
  --query "value[].{Name:name, Workspace:workspaceId, Storage:storageAccountId, `
                    Categories:logs[?enabled].category}" -o json
```

⭐ **Whatever comes back is now in scope for classification, retention, access review, residency and
eDiscovery** — and it is very often a Log Analytics workspace half the IT department can read, or a
storage account with `allowSharedKeyAccess` still enabled, which is the same anonymous-credential
problem as [`../azure-openai/`](../azure-openai/) §3.

**The system prompt is the other unclassified asset:**

```
The system prompt contains:  business rules · tone · tool descriptions ·
                             sometimes internal terminology and thresholds
⭐ It is NOT a secret        an injection attack can often surface it
⭐ It IS intellectual property, and it IS reconnaissance for an attacker
```

⭐ **Design so that extraction is embarrassing, not catastrophic.** If the system prompt contains a
credential, an endpoint, or a rule whose disclosure defeats a control, the architecture is wrong —
the prompt is not an access boundary. Put secrets in
[`../../30-identity-and-nhi/key-vault/`](../../30-identity-and-nhi/key-vault/) and authorisation in
RBAC, and treat the system prompt as *configuration that will eventually be read aloud*.

**Finally, the security properties of the Content Safety resource itself** ✅:

- ⭐ **Managed identity is enabled automatically** when the resource is created — so there is no
  excuse for a key.
- **CMK / BYOK** is supported for encryption at rest.
- ⚠ ✅ **It cannot be used to detect illegal child exploitation imagery** — that is out of scope for
  the product and needs the appropriate reporting path, not a technical control.

---

## 7. What breaks

**"Content filtering is enabled" accepted as a finding.** §4 — read the thresholds.

**A deployment with no RAI policy attached.** §4 — the one quoted back in an incident.

**Guardrails assumed to cover every language.** §5 — ⭐ **the highest-value miss in the topic.**

**Designing for a region where the feature does not exist.** §5.

**Building on a preview API with no 90-day plan.** §5 — the deprecation clock is documented.

**Custom categories (standard) in the synchronous path.** §5 — 5 RPS on the paid tier.

**Treating protected material as an input control.** §4 — it scans completions, 110-char minimum.

**Assuming humans read every prompt.** §2 — automated review is the default, and that content is
**not stored and not used for training** ✅.

**Applying for modified abuse monitoring reflexively.** §3 — you trade content exposure for less
accurate abuse detection and a determination you may have to argue.

**Unclassified prompt logs.** §6 — a data store with no owner, retention or access review.

**Secrets in the system prompt.** §6 — it is not an access boundary.

**Confusing safety with security.** Content filtering addresses harmful output; it does not stop a
hijacked instruction ([`../prompt-injection/`](../prompt-injection/)) or data leaving
([`../sensitive-data-leakage/`](../sensitive-data-leakage/)).

---

## 8. Customer discovery questions

1. Which **languages** does this workload serve, and which guardrails cover them? *(§5.)*
2. Are the **severity thresholds** at default, and can I see any custom RAI policy definition?
3. Is any deployment running with **no policy attached**?
4. Where do **prompts and completions** land, who can read that store, and for how long?
5. Is the workload eligible for, and does it actually need, **modified abuse monitoring**?
6. Do you know that **human review is the exception** and is **JIT-approved on SAWs**?
7. For EEA workloads — do you know reviewers are **located in the EEA**? *(§2 — often the answer.)*
8. Does the **system prompt** contain anything whose disclosure would matter?
9. Are you depending on any **preview** guardrail, and what happens at its 90-day deprecation?
10. Is **Prompt Shields** scanning documents as well as prompts, and how many? *(Limit is five.)*

---

## 9. Remember it

**Hook — "The prompt is a data asset nobody classified."** And the configuration half:
⭐ **the guardrails have a language and a region.**

**Analogy — a smoke detector that only hears English.** The building has detectors, the compliance
folder says "fire detection: installed", and the certificate is on the wall. ⭐ **But three of the
detectors only respond to someone shouting "fire" in English**, and two floors were built in a region
where that model was never sold. **Nothing is broken, nothing alarms, and the inspection passes** —
because the inspection asked *whether* detectors exist, not *what they can hear and where they were
available*.

**The one thing:** ⭐ **ask which languages the workload serves, then check them against the supported
list.** Groundedness detection, protected material and custom categories are **English only**, and
the general models are tested on eight languages. **In any multinational tenant, "guardrails enabled"
is true and a large share of users are unprotected** — and this is invisible to every dashboard,
every policy export and every configuration review. It takes one question to find and nobody asks it.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. Name the four components of abuse monitoring, in order.
2. Is human review the default? What happens to content reviewed by automated means?
3. Which two access controls gate human review, and which repo topic are they the same pattern as?
4. What does Microsoft commit to for EEA deployments that goes beyond data residency?
5. What is the stated cost of modified abuse monitoring?
6. Which three Content Safety features are English only?
7. What is the character minimum on protected material detection, and what does it reveal?
8. What does the task adherence API detect, and what does it complement?
9. What is the deprecation cadence for preview and GA API versions?
10. Why can "we'll add groundedness later" be impossible?
11. What is the rate limit trap in custom categories (standard)?
12. Why is the system prompt not an access boundary?

<details>
<summary>Answers</summary>

1. **Content classification → abuse pattern capture → review and decision → notification and action.**
2. ⭐ **No — automated review is the default.** Content reviewed that way is **not stored by the abuse
   monitoring system and not used to train models.**
3. **Secure Access Workstations (SAWs)** and **Just-In-Time approval by team managers** — ⭐ the same
   pattern as **PIM** and privileged access workstations.
4. ⭐ **The human reviewers are located in the EEA** — reviewer residency, not just data residency.
5. ⚠ **Abuse detection may be less accurate**, and you must still be ready to respond to a
   notification to avoid service interruption.
6. ⭐ **Protected material, groundedness detection, and custom categories (standard).**
7. **110 characters**, and it applies to **completions, not user prompts** — it is an output
   plagiarism control, not an input filter.
8. ⭐ **Agent tool use that is misaligned, unintended or premature.** It complements agent *identity*:
   identity says which tools may be called, task adherence asks whether this call was appropriate now.
9. ⭐ **90 days** — a new preview deprecates the previous preview, a new GA deprecates the prior GA.
10. ⭐ **Groundedness detection is only available in a handful of regions**, which may not include the
    one the workload is legally required to run in.
11. ⭐ **5 RPS on the paid S0 tier — the same as free F0**, while moderation and Prompt Shields get
    1000 RP10S. It cannot sit in a high-volume synchronous path.
12. Because ⭐ **an injection attack can surface it.** Design so extraction is embarrassing, not
    catastrophic: secrets belong in Key Vault, authorisation in RBAC.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — deploy Content Safety; call **Prompt Shields** with a document as well as a prompt;
  call **groundedness detection** with a deliberately unsupported claim and record the verdict.
  ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — send the *same* harmful prompt in **English and in an untested language** and
  record the difference in what is caught. **That single side-by-side is the §5 argument, and it is
  the most persuasive artifact in this topic.**
- **`security/`** — RAI policy definitions per deployment (not names); deployments with no policy;
  language/region coverage matrix against the actual user base; prompt-log store classified with
  owner, retention and access list; system prompt reviewed for anything load-bearing.
- **`operations/`** — preview-API deprecation calendar with 90-day dates; abuse-notification response
  runbook naming who argues a determination.
- **`architecture-decisions/`** — ADR: modified abuse monitoring applied for or deliberately declined,
  **with the accuracy trade recorded**; guardrail coverage accepted per language.
- **`customer-use-cases/`** — §8 answered; the language-coverage gap presented as a finding.

# Azure AI Services (the non-LLM ones)

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The forgotten half of the AI estate.** Everyone secures the chatbot; these services process
> passports, contracts, recorded calls and faces — and are usually deployed by a business unit with
> an API key.
> Shares its entire control model with [`../azure-openai/`](../azure-openai/), which is the point.

---

## 1. What it is

The **pre-LLM Azure AI services** — task-specific models you call like any other API:

| Service | What it processes | ⭐ Sensitivity in practice |
|---|---|---|
| **Document Intelligence** | invoices, receipts, contracts, **IDs and passports** | ⭐⭐ **the highest in the estate** |
| **Speech** | recorded calls, meetings, voicemail | ⭐⭐ often regulated, often consented-for once |
| **Vision** | photos, CCTV frames, uploaded images | ⭐ |
| **Face** | ⚠ **biometric identifiers** | ⭐⭐⭐ ⚠ **Limited Access — see §5** |
| **Language** | tickets, emails, chat transcripts | ⭐ |
| **Translator** | anything, in any language | ⭐ |
| **Content Safety** | your moderation path | — |

⭐ **Document Intelligence deserves the first look in any AI security review**, because it is
routinely pointed at the exact document types a regulator cares about, and it is routinely stood up
by a finance or HR team who wanted to stop typing.

---

## 2. ⭐ The good news: it is the same control model

**Every one of these is a `Microsoft.CognitiveServices` account** — the same resource type as a
Foundry/OpenAI resource. ⭐ **So every control you learned in
[`../azure-openai/`](../azure-openai/) §3 applies unchanged:**

| Control | Same here? |
|---|---|
| **API key vs Entra ID** | ✅ identical — and keys are still the default |
| ⭐ **`disableLocalAuth = true`** | ✅ identical, and still the highest-value boolean |
| **Conditional Access bypassed by keys** | ✅ ⭐ **identical, and identically overlooked** |
| **Private endpoints / `publicNetworkAccess`** | ✅ identical |
| **Customer-managed keys** | ✅ available on most |
| **Managed identity for the caller** | ✅ identical |

> ⭐ **This is the single most useful realisation in the topic, and it is genuinely reassuring:
> there is no second security model to learn.** The AI estate has one identity story, and these
> services are inside it. What differs is *governance attention*, not *mechanism*.

⚠ **One gotcha specific to these services**: Entra ID token authentication generally requires the
resource to have a **custom subdomain** rather than a regional endpoint. **Verify current behaviour**
before promising a key-free migration — it is the usual reason a team says "we tried Entra auth and
it didn't work" and fell back to keys.

---

## 3. Worked example — the whole-estate audit, not just the chatbot

⭐ **Widen the query you already ran.** Most reviews filter to `OpenAI` or `AIServices` and miss
everything else:

```bash
az cognitiveservices account list --query "[].{Name:name, Kind:kind, RG:resourceGroup, \
    LocalAuthDisabled:properties.disableLocalAuth, \
    PublicAccess:properties.publicNetworkAccess, \
    Subdomain:properties.customSubDomainName}" -o table
```

```
Name              Kind                 LocalAuthDisabled  PublicAccess  Subdomain
----------------  -------------------  -----------------  ------------  -----------------
foundry-prod      AIServices           True               Disabled      foundry-prod      ✅
di-invoices       FormRecognizer       False              Enabled       (null)            <-- ⚠⚠⚠
speech-callctr    SpeechServices       False              Enabled       (null)            <-- ⚠⚠
lang-tickets      TextAnalytics        True               Disabled      lang-tickets      ✅
```

⭐ **Row two is the finding of the entire engagement.** `di-invoices` is **Document Intelligence**:
keys enabled, publicly reachable, no custom subdomain — so it **cannot** use Entra ID even if
somebody wanted to. **Anyone with the key, from anywhere, can submit documents and read results, with
no attribution and no Conditional Access.** And it is processing invoices, which in most
organisations means bank details.

**Row three is the second finding.** A Speech resource for the call centre, same posture, processing
**recorded customer calls** — which in many jurisdictions were consented for *one* purpose.

**Then find who is calling them:**

```bash
# Are these being called with keys? Look for the absence of an identity claim.
az monitor diagnostic-settings list --resource <cognitiveServicesResourceId> \
  --query "value[].{Name:name, Enabled:logs[?enabled].category}" -o table
```

⭐ **If diagnostic settings are empty, there is no record of the calls at all** — no attribution, no
volume baseline, no way to answer "how many passports went through this last quarter."

---

## 4. ⭐ Worked example — the data-flow question nobody asks

**These services are usually the middle of a pipeline, and the pipeline is where the exposure is:**

```
Scanned passport  →  Blob storage  →  Document Intelligence  →  extracted JSON  →  ???
      ⭐ ①                ⭐ ②                                        ⭐ ③
```

| Point | The question | The usual answer |
|---|---|---|
| ⭐ ① **Input** | Where does the source document live, for how long? | "In a storage account" — ⚠ often unclassified, often shared-key |
| ⭐ ② **Transit** | Public endpoint or private? | ⚠ Public, per §3 |
| ⭐ ③ **Output** | ⭐ **Where does the extracted JSON go, and who can read it?** | ⭐ **Nobody has thought about it** |

⭐ **Point ③ is the finding, and it is counter-intuitive: the output is often more dangerous than the
input.** A scanned passport is an image in a storage account. **The extracted JSON is the same
passport as structured, queryable, searchable fields** — name, number, date of birth, expiry — sitting
in whatever store the developer chose, usually with no classification and no retention.

```powershell
# Where does the output land, and is that store governed?
az storage account list --query "[].{Name:name, Public:publicNetworkAccess, \
    SharedKey:allowSharedKeyAccess, Https:enableHttpsTrafficOnly, \
    Delete:deleteRetentionPolicy.enabled}" -o table
```

⭐ **`SharedKey: True` on the output store is the same anonymous-credential problem as an API key**,
one layer down — [`../private-ai-networking/`](../private-ai-networking/) §4. **Structured PII behind
an anonymous credential is a materially worse finding than the scanned image was.**

---

## 5. ⚠ Face, biometrics, and the one place the law says no

⚠ **Face and speaker recognition sit behind Microsoft's Limited Access programme** — registration and
an approved use case are required, and some capabilities are not available at all. **Verify the
current gating before designing anything.**

⭐ **And this is where [`../ai-governance/`](../ai-governance/) §6 stops being abstract.** Biometric
identification is the clearest example of a capability that lands in the EU AI Act's **prohibited**
or **high-risk** tiers depending on use — which means:

```
A Vision or Face deployment is not just a security question.
⭐ It is the one AI capability where the answer may be "you may not do this at all",
   and that answer comes from the legal team, not from you.
```

⭐ **Knowing to route a face-recognition request to legal before designing it is a senior judgement**,
and it costs nothing to demonstrate. **The junior answer is a private endpoint and a managed
identity for something that should never have been built.**

⚠ Re-check both the Limited Access terms and the Act's current status (§6 of
[`../ai-governance/`](../ai-governance/) — parts are provisional) before advising.

---

## 6. What breaks

**Auditing only OpenAI/Foundry resources.** §3 — widen the `kind` filter.

**Document Intelligence with keys and public access.** §3 — the highest-value finding.

**No custom subdomain.** §2 — Entra ID auth is not even possible, so keys are permanent.

**Nobody governs the output store.** §4 — ⭐ structured PII is worse than the source image.

**Shared key access on the output storage.** §4.

**No diagnostic settings.** §3 — no attribution and no volume baseline.

**Speech reprocessing recorded calls** consented for another purpose.

**Designing face recognition without legal.** §5.

**Assuming a second security model.** §2 — it is the same one, applied with less attention.

**Business-unit-owned AI resources.** ⭐ The root cause of every row above: these were stood up by
people solving a workflow problem, outside the process that governs the chatbot.

---

## 7. Customer discovery questions

1. List **every** `CognitiveServices` account, not just OpenAI. *(§3.)*
2. Which of them have **`disableLocalAuth`** false and **public access** enabled?
3. Do they have a **custom subdomain** — i.e. is Entra auth even possible? *(§2.)*
4. ⭐ **What does Document Intelligence process, and where does the output go?** *(§4.)*
5. Is the **output store** classified, private, and shared-key-disabled?
6. Are **diagnostic settings** on? Can you say how many documents were processed last quarter?
7. What was the **Speech** data originally consented for?
8. Is any **face or biometric** capability in use or planned — and has legal seen it? *(§5.)*
9. Who **owns** each of these resources, and did security ever review them?

---

## 8. Remember it

**Hook — "Same controls, less attention."** One security model, two levels of scrutiny.

**Analogy — the safe in the boardroom and the filing cabinet in accounts.** Everyone can see the
safe; it has a combination, a policy, and an audit log. ⭐ **The filing cabinet in accounts holds
photocopies of every passport and bank detail, has a key kept in the drawer above it, and was bought
by the office manager** — because it solved a problem and nobody thought of it as security equipment.
**Document Intelligence is the filing cabinet.**

**The one thing:** ⭐ **the extracted output is more dangerous than the input.** A scanned passport is
an image; the extracted JSON is that passport as **structured, queryable, searchable fields**, sitting
in a store nobody classified. Every review looks at the source documents and the service
configuration, and stops before the output. **Ask where the JSON goes, and who can read it** — it is
one question, it takes ten seconds, and it regularly finds a worse exposure than the one that
prompted the review.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Which resource type are all of these, and why does that matter?
2. Name three controls that transfer unchanged from Azure OpenAI.
3. Which service should you look at first in a review, and why?
4. What does a missing custom subdomain prevent?
5. Trace the three points in the data flow. Which is most often ungoverned?
6. Why is the extracted output more dangerous than the source document?
7. What is the storage equivalent of an API key?
8. What is special about Face and biometric capabilities?
9. What is the root cause of most findings in this topic?

<details>
<summary>Answers</summary>

1. ⭐ **`Microsoft.CognitiveServices`** — the same as Foundry/OpenAI, so **there is no second security
   model to learn**.
2. Any three of: **API key vs Entra ID**, ⭐ **`disableLocalAuth`**, **Conditional Access not applying
   to keys**, **private endpoints / public network access**, **CMK**, **managed identity**.
3. ⭐ **Document Intelligence** — it processes invoices, contracts, IDs and passports, and is usually
   deployed by a business unit.
4. ⭐ **Entra ID token authentication** — without it the resource is stuck on keys permanently.
5. **Input document store → transit → output store.** ⭐ **The output store.**
6. ⭐ The image is unstructured; the JSON is the same PII as **structured, queryable, searchable
   fields** in a store nobody classified or set retention on.
7. ⭐ **`allowSharedKeyAccess`** — an anonymous credential, one layer down.
8. ⚠ They are behind **Limited Access**, and ⭐ biometric identification is the capability where the
   EU AI Act's answer may be **"not at all"** — a legal question before a design question.
9. ⭐ **Business-unit ownership.** They were stood up to solve a workflow problem, outside the
   governance that covers the chatbot.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — the §3 estate-wide audit across every `kind`, then the §4 output-store trace for one
  real pipeline. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — call a Document Intelligence resource with a **key** and show the log cannot
  attribute the caller; add a **custom subdomain**, switch to **managed identity**, set
  `disableLocalAuth`, and show the identity appear. **The same contrast as
  [`../azure-openai/`](../azure-openai/), on the resource that actually holds regulated data.**
- **`security/`** — full `CognitiveServices` inventory with `disableLocalAuth`, public access,
  subdomain and owner; output-store classification and access list; diagnostic settings state.
- **`operations/`** — resource ownership register; retention on both input and output stores; volume
  baselines so an anomaly is visible.
- **`architecture-decisions/`** — ADR: Entra-only auth with custom subdomains mandatory; output stores
  classified and private by default; biometric capabilities require legal sign-off.
- **`customer-use-cases/`** — §7 answered; the "where does the JSON go" finding written up as a
  standalone deliverable.

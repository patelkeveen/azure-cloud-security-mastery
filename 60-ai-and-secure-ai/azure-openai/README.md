# Azure OpenAI / Microsoft Foundry

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10**.
> ⚠ **The product was renamed and restructured.** Material older than this year uses names that no
> longer exist. **SC-500 core.**

---

## 1. ⚠ What it is called now ✅

```
Azure AI Studio  →  Azure AI Foundry  →  MICROSOFT FOUNDRY
                                          └── "Azure OpenAI in Foundry Models"
```

| Then | Now ✅ |
|---|---|
| Azure OpenAI **resource type** | ⭐ **Foundry resource type** |
| Azure AI User / Owner / Account Owner / Project Manager | ⭐ **Foundry User / Owner / Account Owner / Project Manager** |
| Azure AI Foundry portal | Microsoft Foundry (the old one is **Foundry classic**) |

**What did *not* change** ✅, and this matters for migration anxiety:

- **Existing Azure OpenAI endpoints, API keys and security configurations are preserved** on upgrade
- ⭐ **Role IDs and core permissions are unchanged by the rename** — only display names moved

**The Foundry resource type is a superset** ✅: broader model catalogue, **Agent Service**, and
evaluation capabilities.

> ⭐ **In an interview, saying "Azure AI Studio" dates you by two renames.** Saying *"Azure OpenAI
> models are now Foundry Models inside Microsoft Foundry, and the role IDs didn't change"* shows you
> tracked it.

---

## 2. Why it exists

Running a frontier model yourself is impractical. The service provides hosted models with an
enterprise wrapper: **your data stays in your tenant boundary**, Azure RBAC governs access, private
networking is available, and it is covered by Azure's compliance commitments.

⭐ **That last point is the entire commercial argument** against staff pasting company data into a
consumer chatbot — see [`../sensitive-data-leakage/`](../sensitive-data-leakage/) §4.

---

## 3. ⭐ The security decision that matters most: API key or Entra ID

Every Foundry endpoint supports **two authentication modes**, and the difference is enormous:

| | **API key** | **Entra ID (Microsoft Entra)** |
|---|---|---|
| What it is | ⭐ A **shared secret** — two per resource | A token for a **real principal** |
| Who used it | ⭐ **Unknowable** — every caller looks identical | The identity is in the token and the logs |
| Rotation | Manual, and it breaks every caller at once | ⭐ None — managed identity |
| Least privilege | ✗ All-or-nothing per resource | ✅ **Azure RBAC**, scoped |
| Conditional Access | ⭐ **Does not apply** | ✅ Applies |
| Revocation | Regenerate the key, break everything | Remove the role assignment |

> ⭐ **Conditional Access does not apply to API-key access.** Every CA policy you wrote in
> [`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/)
> is bypassed by a caller holding the key. That single fact should decide the design, and it is the
> strongest argument you can make in a review.

**The target state:**

```bash
# 1. Disable local (key) auth entirely on the resource
az resource update --ids <foundryResourceId> \
  --set properties.disableLocalAuth=true

# 2. Grant the workload's managed identity a data-plane role instead
az role assignment create --assignee <managedIdentityPrincipalId> \
  --role "Cognitive Services OpenAI User" \
  --scope <foundryResourceId>
```

```csharp
// 3. No key anywhere in the application
var client = new AzureOpenAIClient(
    new Uri("https://my-foundry.openai.azure.com/"),
    new DefaultAzureCredential());
```

⭐ **`disableLocalAuth = true` is the single most valuable setting on the resource**, and it is one
boolean. Audit it across the estate:

```bash
az cognitiveservices account list --query "[].{Name:name, RG:resourceGroup, \
    Kind:kind, LocalAuthDisabled:properties.disableLocalAuth, \
    PublicAccess:properties.publicNetworkAccess}" -o table
```

```
Name             RG          Kind      LocalAuthDisabled  PublicAccess
---------------  ----------  --------  -----------------  ------------
foundry-prod     rg-ai-prod  AIServices  True             Disabled      ✅
foundry-dev      rg-ai-dev   OpenAI      False            Enabled       <-- ⚠⚠
```

**Row two is the finding**: keys enabled, publicly reachable. **Anyone with the key, from anywhere,
with no Conditional Access and no attribution.**

---

## 4. Data-plane roles — least privilege for models ✅

| Role | Grants |
|---|---|
| **Cognitive Services OpenAI User** | ⭐ **Inference only** — what an application needs |
| Cognitive Services OpenAI Contributor | Inference **plus** creating deployments and fine-tunes |
| **Foundry User / Owner / Project Manager** | Foundry platform roles (renamed; IDs unchanged) |
| Cognitive Services Contributor | Control plane — ⚠ **can read keys** |

⭐ **"Cognitive Services Contributor" can read the API keys**, which silently defeats the whole
Entra-ID design. Granting it to an application is a common and quiet mistake — check for it
explicitly in any review.

---

## 5. Deployment types and the security angle

⚠ Deployment type names and options move — **verify current options before quoting**. The stable
security-relevant distinctions:

| Consideration | Why security cares |
|---|---|
| **Data residency / region** | Which jurisdiction processes the prompt |
| **Provisioned versus consumption** | Capacity is also a **denial-of-wallet** control |
| **Model version pinning** | ⭐ Auto-upgrade changes behaviour under you — including safety behaviour |

⭐ **Quota is a security control, not just a cost control.** An uncapped consumption deployment
reachable with a leaked key is a **denial-of-wallet** attack: the attacker's cost is zero, yours is
per token. Set quota deliberately.

---

## 6. Content filtering and abuse monitoring

Foundry applies configurable **content filters** on prompts and completions across harm categories,
plus **Prompt Shields** for jailbreak and indirect injection —
[`../prompt-injection/`](../prompt-injection/) §5.

⚠ **Filter configuration can be modified, and exemptions can be requested.** In a review, check
**what the filters are actually set to**, not that the feature exists — a resource with everything
dialled down is materially different from the default.

⭐ **Content filtering is a safety control, not a security control.** It addresses harmful output; it
does not stop a hijacked instruction, and it does not stop data leaving. Conflating the two is a
common category error.

---

## 7. What breaks

**API keys in production.** §3 — no attribution, no CA, no least privilege.

**Not setting `disableLocalAuth`.** The key path stays open even after wiring up managed identity.

**Granting Cognitive Services Contributor** to an application. §4 — it can read the keys.

**Public network access enabled.** Combined with keys, globally reachable. See
[`../private-ai-networking/`](../private-ai-networking/).

**No quota ceiling.** Denial of wallet.

**Auto-upgrading model versions** in a regulated workload without re-evaluation.

**Assuming content filters are at defaults.** Verify.

**Using stale product names.** §1 — and worse, following stale *instructions* that reference removed
portal paths.

**Treating content filtering as security.** §6.

---

## 8. Customer discovery questions

1. Is **`disableLocalAuth`** true on every Foundry/OpenAI resource? *(§3 — run the query.)*
2. Is **public network access** disabled, with private endpoints?
3. Which identities hold **Cognitive Services Contributor**? *(They can read keys.)*
4. Are applications using **managed identity**, or keys in configuration?
5. Are **quotas** set, and would a leaked key produce an unbounded bill?
6. Are model versions **pinned**, or auto-upgrading?
7. What are the **content filter settings** — defaults, or modified?
8. Are prompts and completions **logged**, where, and for how long?
9. Has the resource been **upgraded to the Foundry type**, and does tooling still assume the old names?

---

## 9. Remember it

**Hook — "Studio → Foundry → Microsoft Foundry,"** and the security line:
**keys bypass Conditional Access.**

**Analogy — a shared office key versus a staff badge.** An **API key is the key under the mat**:
everyone who has it is indistinguishable, nobody can tell who came in, and changing the lock locks
out everybody at once. **Entra ID authentication is a badge** — it names the holder in the log,
respects the door policies you already wrote, and can be revoked for one person without disturbing
anyone else. **`disableLocalAuth = true` is bricking up the space under the mat.**

**The one thing:** ⭐ **Conditional Access does not apply to API-key access.** Every device
compliance, MFA and location policy you built is bypassed by a caller holding a key — so the AI
endpoint sits outside your entire access-control investment until local auth is disabled. **That is
the argument that wins the design conversation.**

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 10. Self-test

1. What is the product called now, and what were its two previous names?
2. What is preserved when upgrading an Azure OpenAI resource to Foundry?
3. Did the rename change role IDs or permissions?
4. Two authentication modes — name three security properties that differ.
5. Which single boolean is the highest-value setting on the resource?
6. Which role can read the API keys, and why does that matter?
7. Which data-plane role should an inference-only application hold?
8. How is quota a security control?
9. Is content filtering a security control?

<details>
<summary>Answers</summary>

1. **Microsoft Foundry.** Previously **Azure AI Foundry**, and before that **Azure AI Studio**.
2. **Endpoints, API keys, state of work and security configurations** — no new resource needed.
3. **No** — only display names changed. **Role IDs and core permissions are unchanged.**
4. **Attribution** (keys are anonymous), **Conditional Access** (does not apply to keys), and
   **least privilege / revocation** (keys are all-or-nothing per resource).
5. **`disableLocalAuth = true`.**
6. **Cognitive Services Contributor** — it can read keys, silently defeating the Entra-ID design.
7. **Cognitive Services OpenAI User** — inference only.
8. An uncapped consumption deployment plus a leaked key is a **denial-of-wallet** attack: the
   attacker pays nothing, you pay per token.
9. **No — it is a safety control.** It addresses harmful output, not hijacked instructions or data
   leaving.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — deploy a Foundry resource; call it with a **managed identity and no key**; then set
  `disableLocalAuth` and prove the key path fails. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — call the endpoint with an API key and show the sign-in log **cannot attribute
  the caller**; repeat with Entra ID and show the identity. **That contrast is the whole §3 argument.**
- **`security/`** — the §3 estate audit (`disableLocalAuth`, `publicNetworkAccess`); Cognitive
  Services Contributor holders; quota ceilings; content filter settings recorded.
- **`operations/`** — model version pinning policy and re-evaluation on upgrade.
- **`architecture-decisions/`** — ADR: Entra ID authentication only, local auth disabled, private
  endpoints, with the Conditional Access argument stated.
- **`customer-use-cases/`** — §8 answered against a real AI deployment.

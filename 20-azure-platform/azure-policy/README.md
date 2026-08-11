# Azure Policy

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The guardrail layer — the only one an Owner cannot bypass.** Read
> [`../azure-rbac/`](../azure-rbac/) §2 first for why that matters.

---

## 1. What it is

**Rules evaluated against a resource's properties, at deployment time and continuously afterwards.**

```
        ┌─ CONDITION ─┐        ┌──── EFFECT ────┐
IF   resource.type == 'Microsoft.Storage/storageAccounts'
AND  properties.allowSharedKeyAccess == true
THEN ⭐ DENY
```

⭐ **Policy asks a different question from RBAC:** not *"may this principal act?"* but **"may this
resource exist in this shape?"** — and the answer binds everyone, including Owners.

---

## 2. ⭐ The effects, in the order you should reach for them

| Effect | What it does | ⭐ When |
|---|---|---|
| **Audit** | records non-compliance, changes nothing | ⭐ **always first** |
| **Deny** | blocks the request | once you know the blast radius |
| **Modify** | ⭐ adds/updates properties or **tags** on write | tagging, defaults |
| **DeployIfNotExists** | ⭐ deploys a missing sub-resource | diagnostic settings, agents |
| **AuditIfNotExists** | flags a missing related resource | detection without change |
| **Disabled** | off, but retained | ⭐ keeping intent visible |
| **Append** | adds fields | narrow uses |

⭐ **"Watch first" is the standing pattern** — the same one recorded in `RETENTION.md` §3b and
observable in every Microsoft security product: **audit mode exists everywhere, and deploying
straight to enforce is the recurring outage.**

⚠ **The one place this repo says otherwise** is approved-model policy in
[`../../60-ai-and-secure-ai/data-poisoning/`](../../60-ai-and-secure-ai/data-poisoning/) §4 — because
an audit finding on an already-deployed poisoned model describes something irreversible. **Audit long
enough to size it, then move.**

---

## 3. ⭐ The three things that surprise people

**① Deny is not retroactive.**

> ⭐ **A `Deny` policy stops *new* non-compliant deployments. It does not touch what already exists.**

Assign a policy denying public storage accounts and **every existing public storage account stays
exactly as it was** — it simply shows as non-compliant. **The policy is a gate on the door, not a
sweep of the building.** Remediating what already exists is a separate act.

**② Compliant ≠ safe. Non-compliant ≠ unsafe.**

⭐ **Compliance measures conformance to the rules you wrote.** A 100% compliant estate with three
policies assigned is 100% compliant with almost nothing. **Always ask "compliant with what, and how
many policies are in scope?"** — the percentage is meaningless without the denominator.

**③ Exemptions are where the real posture lives.**

```bash
# ⭐ The most under-audited object in Azure governance
az policy exemption list --disable-scope-strict-match \
  --query "[].{Name:name, Scope:scope, Category:exemptionCategory, \
               Expires:expiresOn, Reason:displayName}" -o table
```

```
Name              Scope                    Category   Expires    Reason
----------------  -----------------------  ---------  ---------  ------------------------
exempt-legacy     /subscriptions/aaaa      Waiver     (null)     legacy app migration      <-- ⚠⚠ no expiry
exempt-sandbox    /…/rg-datasci            Mitigated  2026-09-30 approved by security      ✅
```

⭐ **A `Waiver` with no expiry is a permanent hole recorded as a temporary one.** It is the governance
equivalent of a firewall rule added "just for today" in 2019 — and it makes the compliance dashboard
green while the control is off.

---

## 4. Worked example — from finding to guardrail

**Take the real finding from
[`../../60-ai-and-secure-ai/azure-openai/`](../../60-ai-and-secure-ai/azure-openai/) §3 — API keys
enabled on AI resources — and make it structurally impossible.**

```json
{
  "if": {
    "allOf": [
      { "field": "type", "equals": "Microsoft.CognitiveServices/accounts" },
      { "field": "Microsoft.CognitiveServices/accounts/disableLocalAuth", "notEquals": "true" }
    ]
  },
  "then": { "effect": "[parameters('effect')]" }
}
```

```bash
# ① AUDIT first - how big is this? (⭐ never skip to Deny)
az policy assignment create -n require-no-local-auth \
  --policy <definitionId> --scope /subscriptions/<sub> \
  --params '{"effect":{"value":"Audit"}}'

# ② Size it
az policy state summarize --resource-group rg-ai-prod \
  --query "value[].results.nonCompliantResources" -o tsv
```

```
7
```

⭐ **Seven existing resources. Now you know that flipping to Deny breaks nothing that exists** (§3 ①)
**but you also know there are seven to remediate separately.**

```bash
# ③ Flip to Deny once the blast radius is known
az policy assignment create -n require-no-local-auth \
  --policy <definitionId> --scope /subscriptions/<sub> \
  --params '{"effect":{"value":"Deny"}}'
```

```
# ④ Prove it - the test that turns configuration into evidence
az cognitiveservices account create -n test-keys -g rg-ai-prod \
  --kind OpenAI --sku S0 -l eastus
```

```
Code: RequestDisallowedByPolicy
Message: Resource 'test-keys' was disallowed by policy 'require-no-local-auth'.
```

⭐ **`RequestDisallowedByPolicy` is the string that means the guardrail is real.** A policy assignment
in the portal is a claim; this error is evidence — the same claim-versus-evidence distinction as
signed commits in
[`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §3.

---

## 5. ⭐ DeployIfNotExists and its identity

**`DeployIfNotExists` and `Modify` change things, so they need a principal — a managed identity
created with the assignment.**

```bash
az policy assignment create -n deploy-diag-settings \
  --policy <definitionId> --scope /subscriptions/<sub> \
  --mi-system-assigned --location eastus \
  --role Contributor --identity-scope /subscriptions/<sub>   # ⭐ read this line again
```

⭐ **That identity holds a real role at a real scope — often Contributor across a subscription.** It
is a non-human identity created by a governance action, and it lands squarely in the inventory problem
from [`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §6:
**nobody requested it, and it will not appear on anyone's access review.**

```powershell
# ⭐ Every policy-assignment identity, and what it can do
az policy assignment list --disable-scope-strict-match `
  --query "[?identity!=null].{Name:name, Scope:scope, PrincipalId:identity.principalId}" `
  -o json | ConvertFrom-Json | ForEach-Object {
    $roles = az role assignment list --assignee $_.PrincipalId --all `
             --query "[].{Role:roleDefinitionName, Scope:scope}" -o json | ConvertFrom-Json
    [pscustomobject]@{ Policy = $_.Name; Roles = ($roles.Role -join ','); At = ($roles.Scope -join ',') }
  }
```

⭐ **Remediation is also not automatic.** A `DeployIfNotExists` policy fixes resources created *after*
assignment; existing ones need an explicit **remediation task** — §3 ① in another costume.

---

## 6. What breaks

**Assigning Deny without auditing first.** §2 — the recurring outage.

**Expecting Deny to fix what exists.** §3 ① — ⭐ it is a gate, not a sweep.

**Quoting a compliance percentage without the denominator.** §3 ②.

**Exemptions with no expiry.** §3 ③ — ⭐ a permanent hole recorded as temporary.

**Never auditing exemptions at all.** ⭐ The most under-audited object in Azure governance.

**Forgetting remediation tasks.** §5 — existing resources stay non-compliant.

**Ignoring policy-assignment managed identities.** §5 — Contributor, unrequested, unreviewed.

**Assigning at subscription scope repeatedly** instead of once at a management group — drift between
subscriptions is guaranteed.

**Using RBAC where Policy belongs.** [`../azure-rbac/`](../azure-rbac/) §2.

**Treating "policy assigned" as evidence.** §4 — ⭐ get the `RequestDisallowedByPolicy`.

---

## 7. Customer discovery questions

1. How many policies are **in scope**, and what is the compliance percentage **of**? *(§3 ②.)*
2. ⭐ **Show me every exemption.** How many have no expiry? *(§3 ③.)*
3. Are policies assigned at **management group** scope or repeated per subscription?
4. Which policies are at **Deny**, and which are still **Audit** years later?
5. Have **remediation tasks** been run for existing resources? *(§5.)*
6. What do the **policy-assignment managed identities** hold, and at what scope?
7. Can you show me a **`RequestDisallowedByPolicy`** from the activity log? *(§4.)*
8. Which of your written policy statements have ⭐ **no Azure Policy behind them**? *(Cross-reference
   [`../../60-ai-and-secure-ai/ai-governance/`](../../60-ai-and-secure-ai/ai-governance/) §5.)*

---

## 8. Remember it

**Hook — "Audit first, then Deny. Deny is a gate, not a sweep."**

**Analogy — building regulations and the inspector.** ⭐ **Policy is the building code: it applies to
the owner too**, which is exactly what RBAC can never do. But notice how a real building code behaves
— ⭐ **new construction must comply; the 1970s block down the road is "non-conforming" and stands
untouched.** That is `Deny` precisely: it stops the next thing being built wrong and does nothing
about what is already there. ⭐ **And an exemption with no expiry is a permanent planning variance
filed as a temporary one** — the register says the rule is in force, and one building is quietly
outside it forever.

**The one thing:** ⭐ **audit the exemptions, not the compliance score.** The dashboard shows green
because things were exempted, not because they were fixed — and a `Waiver` with no expiry is a
control that has been switched off while still appearing to be on. **It takes one command
(`az policy exemption list`), almost nobody runs it, and the output is usually the most interesting
governance document in the tenant.**

**Runner-up:** ⭐ **`Deny` does not touch what already exists.** Assign it and the estate is still
non-compliant; remediation is a separate act you have to schedule.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What question does Policy answer that RBAC does not?
2. Name the effects and say which you reach for first.
3. ⭐ Does `Deny` fix existing non-compliant resources?
4. Why is a compliance percentage meaningless on its own?
5. ⭐ What makes an exemption a permanent hole, and how do you list them?
6. Which effects require a managed identity, and what is the risk?
7. What is the difference between a policy assignment and a remediation task?
8. What string proves a guardrail is real?
9. Where is the one place this repo prefers Deny over Audit-first, and why?
10. Why assign at management group rather than per subscription?

<details>
<summary>Answers</summary>

1. ⭐ **"May this resource exist in this shape?"** — and it binds Owners, which RBAC never does.
2. **Audit, Deny, Modify, DeployIfNotExists, AuditIfNotExists, Disabled, Append.** ⭐ **Audit first,
   always** — except §2's noted exception.
3. ⭐ **No.** It gates **new** deployments; existing resources become non-compliant and stay.
4. ⭐ Because it is compliance **with the policies you assigned** — 100% against three policies means
   almost nothing. Always ask for the denominator.
5. ⭐ A **`Waiver` with no `expiresOn`**. List with **`az policy exemption list
   --disable-scope-strict-match`**.
6. ⭐ **`DeployIfNotExists` and `Modify`.** The assignment's managed identity often holds
   **Contributor at subscription scope**, unrequested and outside any access review.
7. The assignment governs **future** resources; ⭐ a **remediation task** brings **existing** ones into
   line.
8. ⭐ **`RequestDisallowedByPolicy`** — configuration becomes evidence.
9. ⭐ **Approved-model policy** for AI — an audit finding on a deployed poisoned model describes
   something **irreversible**.
10. ⭐ One assignment, inherited by every subscription **including future ones** — per-subscription
    assignment guarantees drift.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §4 audit-size-deny-prove sequence end to end. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — assign a `Deny` policy and **show an existing non-compliant resource surviving
  untouched**, then run a remediation task and show the difference. **That contrast is §3 ① and it is
  the misconception this topic exists to kill.** Then add an exemption and watch the compliance score
  go green with nothing fixed.
- **`security/`** — exemption register with expiry dates and owners; policies at Audit for more than
  90 days; policy-assignment identity permissions; the ⭐ policy-statement-to-Azure-Policy map.
- **`operations/`** — remediation task schedule; exemption expiry review; promotion path from Audit to
  Deny with a blast-radius measurement recorded.
- **`architecture-decisions/`** — ADR: guardrails at management group scope; exemptions require an
  expiry and a named owner.
- **`customer-use-cases/`** — §7 answered; the exemption register presented as the headline finding.

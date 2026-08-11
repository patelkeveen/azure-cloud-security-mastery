# Bicep

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Compiles to ARM — read [`../azure-resource-manager/`](../azure-resource-manager/) first.
> ⭐ **Compare deliberately with [`../terraform/`](../terraform/): the state model is the difference
> that matters.**

---

## 1. What it is

**A domain-specific language that transpiles to ARM JSON.** Same API, same RBAC and Policy
evaluation, far less typing.

```bicep
resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name:     stName
  location: location
  sku:      { name: 'Standard_LRS' }
  kind:     'StorageV2'
  properties: {
    allowSharedKeyAccess:  false     // ⭐ the control, in the artifact
    publicNetworkAccess:   'Disabled'
    minimumTlsVersion:     'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}
```

⭐ **The security value of IaC is not the automation — it is that the control becomes reviewable
text.** `allowSharedKeyAccess: false` in a pull request is a control you can require, diff, and prove
was present on a given date. **The same setting made in the portal is a fact with no history.**

---

## 2. ⭐ No state file — and why that is the headline difference

> **Bicep has no state file. ⭐ Azure *is* the state.**

Every deployment is a `PUT` against ARM, which compares the declared shape with reality and converges
— the idempotency property from
[`../../00-foundations/data-formats-and-apis/`](../../00-foundations/data-formats-and-apis/) §4.

⭐ **The security consequence is large and it is the reason to prefer Bicep when the choice is
open:**

| | Bicep | Terraform |
|---|---|---|
| State | ⭐ **none — ARM holds it** | ⭐ **a file containing everything, including secrets** |
| Secret exposure surface | deployment history (§4) | ⭐ state file **plus** history |
| Drift | ⭐ next deploy converges | drift vs state, then a plan |
| Blast radius of losing state | ⭐ **nothing to lose** | ⚠ recovery is painful |

⭐ **"There is no state file to protect" removes an entire class of finding** — see
[`../terraform/`](../terraform/) §2 for what that class looks like.

---

## 3. Worked example — `what-if` as the review gate

```bash
# ⭐ The dry run. This is Bicep's -WhatIf, and it is the whole safety story.
az deployment group what-if -g rg-prod -f ./main.bicep -p ./prod.bicepparam
```

```
Resource changes: 1 to create, 2 to modify, ⭐ 1 to delete.

  + Microsoft.Storage/storageAccounts/stprodnew

  ~ Microsoft.KeyVault/vaults/kv-prod
      ~ properties.enablePurgeProtection:  true => false        <-- ⚠⚠⚠ read this line

  - Microsoft.Network/networkSecurityGroups/nsg-prod-app       <-- ⚠⚠ deletion
```

⭐ **The `~` line is why `what-if` belongs in the pipeline as a gate rather than as a log.** A
template change that silently disables Key Vault purge protection is a **recovery-path change**
([`../resource-locks/`](../resource-locks/) §4) and it is one word in a diff nobody reads.

> ⭐ **Run `what-if` in the PR, post the output as a comment, and require a human to acknowledge any
> `-` or any `~` on a security property.** That converts IaC from "faster changes" into "reviewed
> changes", which is the actual security benefit.

⚠ `what-if` is a prediction, not a guarantee — provider behaviour and runtime values can differ. **It
is a strong signal, not a contract.**

---

## 4. ⭐ `@secure()` and the history that remembers

```bicep
@secure()                          // ⭐ keeps it out of deployment history
param sqlAdminPassword string

@description('Prefer this: no secret passes through the template at all')
resource kvRef 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-prod'
}
```

⭐ **A parameter *without* `@secure()` is retained in deployment history and readable by anyone with
read access to the resource group** —
[`../azure-resource-manager/`](../azure-resource-manager/) §4. **This is the same append-only lesson
as git history and container image layers**, and the fix is the same: rotate what leaked, then stop
producing it.

```bash
# ⭐ Audit: has any deployment recorded a plaintext secret-shaped parameter?
az deployment group list -g rg-prod --query "[].name" -o tsv | ForEach-Object {
  $p = az deployment group show -g rg-prod -n $_ --query "properties.parameters" -o json
  if ($p -match '(?i)password|secret|key|token|connectionstring') { "$_ <-- ⚠ inspect" }
}
```

⭐ **Best of all: do not pass the secret.** Reference Key Vault from the parameter file, or use a
managed identity so no secret exists —
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/).

---

## 5. Modules, and where the guardrails actually live

```bicep
module storage 'br/public:avm/res/storage/storage-account:0.9.1' = {
  //                                                    ▲
  //  ⭐ pinned version - an unpinned module is someone else's code in your deploy
  name: 'storage-deploy'
  params: { name: stName, allowSharedKeyAccess: false }
}
```

⭐ **A module registry is a supply chain** — the same argument as pinned GitHub Actions
([`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §4) and pinned
container images
([`../../00-foundations/virtualization-and-containers/`](../../00-foundations/virtualization-and-containers/) §4).
**Pin the version, and prefer a private registry for anything you rely on.**

⚠ **But do not mistake modules for enforcement.** A module encodes good defaults; ⭐ **nothing stops
somebody deploying a raw resource that bypasses it.** Enforcement lives in
[`../azure-policy/`](../azure-policy/) — modules are the paved road, Policy is the fence.

---

## 6. What breaks

**Parameters without `@secure()`.** §4 — ⭐ readable in deployment history forever.

**`what-if` logged but not gated.** §3 — the `~` line nobody reads.

**Unpinned module versions.** §5 — someone else's code in your deployment.

**Believing modules enforce anything.** §5 — ⭐ they are defaults, not fences.

**Complete-mode deployments.** [`../azure-resource-manager/`](../azure-resource-manager/) §4 —
deletion by template.

**Old `apiVersion` in resource declarations.** ⭐ Newer security properties cannot be set at all.

**The deploy identity holding Owner.** The pipeline becomes the most privileged principal —
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §5.

**Secrets in `.bicepparam` committed to git.** ⭐ Git never forgets — rotate.

**IaC for creation only,** with everything since changed by hand — the template is now fiction.

---

## 7. Customer discovery questions

1. Is **`what-if`** run in the PR, and does anyone **gate** on deletions or security-property changes?
2. Are any parameters carrying secrets **without `@secure()`**? *(§4 — run the audit.)*
3. Are modules **pinned**, and from a registry you control? *(§5.)*
4. What does the **deploy identity** hold, and is it federated or secret-based?
5. Is the estate **actually described** by the templates, or has it drifted?
6. Are `apiVersion`s recent enough to express current security properties?
7. Which controls do you believe templates enforce that ⭐ **only Policy can**? *(§5.)*

---

## 8. Remember it

**Hook — "No state file. Azure is the state."** And: **`what-if` is the gate, not the log.**

**Analogy — a recipe versus a photograph of the finished dish.** ⭐ **Bicep is the recipe**: it says
what the dish must be, and running it again fixes whatever drifted. **Terraform additionally keeps a
photograph of the last dish it made** — useful, and now you own a photograph that shows every
ingredient including the ones you wanted secret. ⭐ **Bicep has no photograph to protect.**

**The one thing:** ⭐ **`what-if` output belongs in the pull request as a gate.** The security value of
IaC is not speed — it is that a change to a security property becomes a **reviewable diff with a date
and an approver**. `enablePurgeProtection: true => false` is one word in a template and a
recovery-path change in production; unreviewed IaC is just a faster way to make it.

**Runner-up:** ⭐ **a parameter without `@secure()` lives in deployment history**, readable by any
Reader.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. What does Bicep compile to, and what does that mean for RBAC and Policy?
2. ⭐ Where is Bicep's state, and what class of finding does that remove?
3. What is `what-if`, and how should it be used differently from how it usually is?
4. Which two symbols in `what-if` output should stop a merge?
5. Is `what-if` a guarantee?
6. ⭐ What happens to a parameter without `@secure()`, and which two earlier topics is that the same
   lesson as?
7. What is the better option than passing a secret at all?
8. Why pin module versions?
9. ⭐ Do modules enforce anything? What does?
10. Why does an old `apiVersion` matter for security specifically?

<details>
<summary>Answers</summary>

1. **ARM JSON**, deployed through the same ARM endpoint — so ⭐ **RBAC then Policy are evaluated
   identically**; Bicep gets no special treatment.
2. ⭐ **There is none — Azure is the state.** It removes the entire ⭐ **state-file exposure** class.
3. A **dry run** predicting changes. ⭐ Use it as a **PR gate requiring acknowledgement**, not as
   pipeline output nobody reads.
4. ⭐ **`-` (deletion)** and **`~` on a security property**.
5. ⚠ **No** — a strong signal; provider behaviour and runtime values can differ.
6. ⭐ It is **retained in deployment history**, readable by any Reader. ⭐ Same as **git history** and
   **container image layers** — append-only records do not forget, and the fix is **rotate**.
7. ⭐ **Do not pass one** — reference Key Vault, or use a **managed identity**.
8. ⭐ A module registry is a **supply chain**; unpinned means someone else's code runs in your
   deployment.
9. ⭐ **No — they are defaults, the paved road.** ⭐ **Azure Policy** is the fence.
10. ⭐ **Newer security properties cannot be set at all** on an old API version.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** — deploy the §1 storage account, then change one security property and read the `what-if`
  diff. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — pass a password as a plain parameter, deploy, and **read it back out of
  deployment history as a Reader**; then add `@secure()` and show it absent. **Same exercise as
  recovering a "deleted" secret from git history — and it lands the same way.**
- **`security/`** — deployment history scanned for secret-shaped parameters; module pin audit; deploy
  identity permissions and credential type; `apiVersion` currency.
- **`operations/`** — `what-if` as a required PR check with named approvers for `-` and `~` changes;
  drift detection cadence.
- **`architecture-decisions/`** — ADR: Bicep over Terraform where the choice is free, ⭐ with the
  state-file argument recorded; Policy for enforcement, modules for defaults.
- **`customer-use-cases/`** — §7 answered; a `what-if` gate proposed as a concrete pipeline change.

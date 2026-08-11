# Terraform

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Contains the single highest-value finding in this domain — §2.**
> Compare with [`../bicep/`](../bicep/) §2 for why the state model is the difference.

---

## 1. What it is

**Cloud-agnostic declarative infrastructure, with an explicit state file.**

```
main.tf ──▶ terraform plan ──▶ compare DESIRED vs ⭐ STATE ──▶ apply ──▶ Azure
                                              ▲
                              ⭐ Terraform's own record of reality
```

⭐ **Terraform does not ask Azure what exists — it asks its state file, then reconciles.** That
indirection is what makes it multi-cloud, and it is the source of every security consideration below.

---

## 2. ⭐ The state file contains your secrets in plaintext

> **Terraform state stores every attribute of every resource it manages — including values marked
> `sensitive` in the configuration. ⭐ `sensitive` hides them from CLI *output*. It does not encrypt
> or omit them from state.**

```json
// terraform.tfstate — an actual excerpt shape
{
  "resources": [{
    "type": "azurerm_key_vault_secret",
    "instances": [{ "attributes": {
        "name":  "sql-admin-password",
        "value": "⭐ THE ACTUAL SECRET, IN PLAINTEXT"
    }}]
  }]
}
```

⭐ **So the state file is a credential store you did not intend to create**, and it is routinely:

```
✗ committed to git             ⭐ and git never forgets — ../../00-foundations/git-and-github/ §2
✗ in a public storage container
✗ in a container with shared key access enabled
✗ readable by every engineer, because "it's just state"
✗ copied to a laptop for a local `terraform apply`
```

**The required posture, and none of it is optional:**

| Control | Why |
|---|---|
| ⭐ **Remote backend** (Azure Storage), never local, never git | one governed copy |
| ⭐ **`allowSharedKeyAccess: false`** on that account | ⭐ Entra auth only — no anonymous credential |
| **Private endpoint**, public access disabled | not reachable from the internet |
| ⭐ **RBAC scoped tightly** — Storage Blob Data Contributor to CI only | it is a secret store, treat it as one |
| **Versioning + soft delete** | state corruption is an outage |
| ⭐ **State locking** (blob lease) | concurrent applies corrupt state |
| **Diagnostic logging on the container** | ⭐ who read the state, and when |

```bash
# ⭐ The audit. Run this before anything else in a Terraform estate.
az storage account show -n <tfstate-account> \
  --query "{Public:publicNetworkAccess, SharedKey:allowSharedKeyAccess, \
            Https:enableHttpsTrafficOnly, Versioning:name}" -o table

az storage container show-permission -n tfstate --account-name <tfstate-account>
```

```
Public    SharedKey   Https
--------  ----------  -----
Enabled   True        True     <-- ⚠⚠⚠ a plaintext secret store on the internet, key-authenticated
```

⭐ **That single row is the finding.** It is the most common serious misconfiguration in a Terraform
estate, it is one query, and the people who own it usually think of the container as "build output".

⚠ **And if state has ever been committed to git or stored publicly: treat every secret in it as
compromised and rotate.** History rewriting does not reach clones —
[`../../00-foundations/git-and-github/`](../../00-foundations/git-and-github/) §2.

---

## 3. Worked example — the plan as a review gate

```bash
terraform plan -out=tfplan          # ⭐ save it, so apply uses exactly what was reviewed
terraform show -json tfplan | jq -r '
  .resource_changes[] | select(.change.actions[] | . == "delete") |
  "DELETE  \(.type)  \(.name)"'
```

```
DELETE  azurerm_network_security_group  nsg_prod_app
DELETE  azurerm_key_vault               kv_prod            <-- ⚠⚠⚠
```

⭐ **`-out=tfplan` then `apply tfplan` is the control**, not a convenience. Running `plan` and then a
bare `apply` means **the thing applied is not the thing reviewed** — state or reality may have moved
between them. **It is a time-of-check-to-time-of-use gap in your change process.**

**Detect replacements, which are the quiet destroyer:**

```bash
terraform show -json tfplan | jq -r '
  .resource_changes[] | select(.change.actions == ["delete","create"]) |
  "⭐ REPLACE  \(.type).\(.name)"'
```

⭐ **A `delete,create` replacement destroys and recreates the resource** — new resource ID, new keys,
lost data, broken role assignments
([`../azure-resource-manager/`](../azure-resource-manager/) §5). **It is one changed immutable
attribute away at all times, and in a plan it looks almost identical to an update.**

---

## 4. Providers and drift

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }   # ⭐ constrain
  }
  backend "azurerm" {
    use_azuread_auth = true        # ⭐ Entra, not a storage key
    # ⚠ no access_key here, ever
  }
}

provider "azurerm" {
  features {}
  use_oidc = true                  # ⭐ workload identity federation, no stored secret
}
```

⭐ **`use_oidc = true` with GitHub Actions removes the deploy secret entirely** —
[`../../30-identity-and-nhi/workload-identity-federation/`](../../30-identity-and-nhi/workload-identity-federation/),
and it fixes the `gh-actions-*` finding from
[`../../60-ai-and-secure-ai/ai-pipeline-nhi/`](../../60-ai-and-secure-ai/ai-pipeline-nhi/) §5.

⚠ **`.terraform.lock.hcl` must be committed.** It pins provider hashes — ⭐ **it is the supply-chain
control for providers**, the same argument as pinned modules, actions and images. A provider is code
that runs with your deploy credentials.

**Drift is a security signal, not just untidiness:**

```bash
terraform plan -detailed-exitcode      # 0 = no drift, 2 = drift, 1 = error
```

⭐ **Unexplained drift means someone changed production outside the pipeline** — cross-reference the
Activity Log ([`../azure-resource-manager/`](../azure-resource-manager/) §3) for **who**. That is a
detection, and almost nobody wires it up.

---

## 5. What breaks

**State in git.** §2 — ⭐ plaintext secrets, permanently, in every clone.

**State container public or shared-key enabled.** §2 — ⭐ the headline finding.

**Assuming `sensitive` protects state.** §2 — it hides CLI output only.

**Broad read access to state.** §2 — it is a secret store.

**No state locking.** Concurrent applies corrupt it.

**`plan` then bare `apply`.** §3 — ⭐ what ran is not what was reviewed.

**Missing a `delete,create` replacement.** §3 — data loss that reads like an update.

**Storage key in the backend config.** §4 — use `use_azuread_auth`.

**Deploy secret instead of OIDC.** §4.

**`.terraform.lock.hcl` not committed.** §4 — unpinned provider code.

**Drift ignored.** §4 — ⭐ someone is changing prod outside the pipeline.

---

## 6. Customer discovery questions

1. ⭐ **Where is state, and who can read it?** *(§2 — then run the storage audit.)*
2. Has state **ever** been in git or a public container? *(§2 — if yes, ⭐ rotate everything in it.)*
3. Is `allowSharedKeyAccess` **false** on the state account, with a private endpoint?
4. Is there **logging** on state reads?
5. Is **state locking** enabled?
6. Does the pipeline use `-out=tfplan` and apply **that file**? *(§3.)*
7. Does anyone check for **`delete,create` replacements** before apply?
8. Is the backend authenticated with **Entra** and the provider with **OIDC**? *(§4.)*
9. Is `.terraform.lock.hcl` committed?
10. Is **drift** detected, and does anyone look up **who** caused it?

---

## 7. Remember it

**Hook — "The state file is a secret store."** Protect it like Key Vault, because that is what it is.

**Analogy — a locksmith's notebook.** ⭐ Terraform works by keeping **a detailed notebook of every
lock it has fitted — including, written out in full, the combination of each one.** The notebook is
genuinely necessary for the work. ⭐ **But teams leave it on the counter, photocopy it into version
control, and let anyone flip through it, because they think of it as *paperwork about the locks*
rather than *the combinations themselves*.** It is the combinations.

**The one thing:** ⭐ **`sensitive = true` hides a value from CLI output; it does nothing to the state
file.** The secret is in state, in plaintext, and state is a blob in a storage account that is far too
often public, shared-key-authenticated, and readable by every engineer. **One command
(`az storage account show`) answers it, the answer is usually bad, and if state was ever in git you
are rotating, not remediating.**

**Runner-up:** ⭐ **`plan -out` then `apply tfplan`** — otherwise what ran is not what was reviewed.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. What does Terraform compare during a plan, and why does that matter?
2. ⭐ What is in the state file, and what does `sensitive = true` actually do?
3. List the required controls on a state backend.
4. If state has been in git, what is the remediation?
5. ⭐ Why is `plan` followed by a bare `apply` a control failure?
6. What does a `delete,create` action mean, and why is it dangerous?
7. What does `use_azuread_auth` replace, and why does it matter?
8. What does `use_oidc = true` remove?
9. ⭐ Why must `.terraform.lock.hcl` be committed?
10. Why is drift a security signal, and what do you correlate it with?

<details>
<summary>Answers</summary>

1. **Desired configuration against its own ⭐ state file**, not against Azure directly — which is why
   state exists and why it must be protected.
2. ⭐ **Every attribute of every managed resource, including secrets, in plaintext.** `sensitive`
   ⭐ **only hides values from CLI output** — state is unaffected.
3. **Remote backend**, ⭐ **`allowSharedKeyAccess: false`**, private endpoint / public access disabled,
   tightly scoped RBAC, versioning + soft delete, ⭐ **state locking**, and read logging.
4. ⭐ **Rotate every secret in it.** History rewriting cannot reach clones, forks or caches.
5. ⭐ **What is applied is not what was reviewed** — state or reality can move between the two
   commands. A time-of-check-to-time-of-use gap.
6. A ⭐ **replacement**: destroy and recreate. New resource ID, new keys, potential data loss, broken
   role assignments — and it looks like an update in a plan.
7. It replaces a ⭐ **storage access key** in the backend config with **Entra authentication**.
8. ⭐ **The stored deploy secret** — workload identity federation instead.
9. ⭐ It **pins provider hashes** — the supply-chain control for code that runs with your deploy
   credentials.
10. ⭐ It means **someone changed production outside the pipeline**. Correlate with the **Activity
    Log** to find who.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — stand up a remote backend correctly: Entra auth, no shared key, private endpoint,
  locking, versioning, read logging. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — create a `azurerm_key_vault_secret`, then **open the state file and read the
  secret in plaintext**. ⭐ **Thirty seconds, and it permanently changes how the team treats that
  container.** Then change an immutable attribute and show the plan turn into a `delete,create`.
- **`security/`** — state backend posture (public access, shared key, RBAC, logging, locking); whether
  state has ever been in git; provider lock file committed; deploy identity credential type.
- **`operations/`** — `plan -out` / `apply tfplan` enforced in the pipeline; replacement detection as
  a gate; drift check on a schedule with Activity Log correlation.
- **`architecture-decisions/`** — ADR: remote state with Entra-only auth and private networking; OIDC
  federation for the deploy identity; ⭐ Bicep preferred where multi-cloud is not required, with the
  state-file argument recorded.
- **`customer-use-cases/`** — §6 answered; the state-container audit as a standalone finding.

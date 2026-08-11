# Resource Groups and Tags

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Two things that look like housekeeping and decide how an incident goes.**
> Scoped by [`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/).

---

## 1. What a resource group actually is

**A lifecycle container with an RBAC scope attached.** Two properties, and both matter:

```
① ⭐ DELETE THE GROUP → delete everything in it     (the lifecycle part)
② ⭐ It is an RBAC and Policy scope                 (the governance part)
```

⭐ **Property ① is why the grouping rule is "things that live and die together"** — not "things owned
by the same team", not "things of the same type". A resource whose lifetime differs from its
neighbours' is in the wrong group, and you find out during a decommission.

⚠ **A resource group is not isolation.** Subscription-scoped rights reach into every group beneath —
[`../azure-rbac/`](../azure-rbac/) §2. **It bounds a delete; it does not bound an attacker.**

**Two facts people get wrong:**

| Fact | ⭐ Consequence |
|---|---|
| A resource group has a **location** | It stores group **metadata** there — ⭐ resources inside can live elsewhere |
| Resources can **reference across groups** | ⭐ Deleting a "spare" group breaks something in another |

---

## 2. ⭐ Tags are not a security control — and they decide the incident anyway

> ⭐ **Anyone with write access to a resource can change its tags.** So a tag cannot enforce anything.
> ⚠ There is one exception worth knowing: **ABAC conditions and some policies read tags**, which
> means a writable tag can influence an authorisation decision — ⭐ **make sure any tag used that way
> is protected by a Deny policy on modification.**

**But at 02:00, tags are the only thing standing between you and a guess:**

```
Alert: unusual outbound traffic from vm-prod-app-07

Without tags:  ⭐ who owns this? what does it do? can I isolate it?
               → an hour of asking people, at night

With tags:     Owner=platform-team  Env=prod  DataClass=confidential
               CostCentre=CC1042    OnCall=teams://…
               → ⭐ isolate now, call the right person, know the stakes
```

⭐ **The mean time to *contain* is bounded by the mean time to *identify the owner*.** That is the
argument for tagging, and it is a security argument — not a finance one. Cross-reference
[`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/).

**The tags that earn their place:**

| Tag | ⭐ Answers |
|---|---|
| `Owner` / `OnCall` | ⭐ **who do I wake up** |
| `Environment` | ⭐ **can I isolate this right now, or will I take down prod** |
| `DataClassification` | ⭐ **how bad is this** |
| `CostCentre` | who pays — and whose budget anomaly this is |
| `ExpiresOn` | ⭐ is this still meant to exist |

---

## 3. Worked example — find what nobody owns

```powershell
# ⭐ Untagged resources: the ones you cannot attribute in an incident
$required = 'Owner','Environment','DataClassification'

$all = az resource list --query "[].{Name:name, Type:type, RG:resourceGroup, Tags:tags}" `
       -o json | ConvertFrom-Json

$gaps = $all | ForEach-Object {
    # ⭐ @() on both sides: a resource with one tag, or one missing tag, must still count
    $have = @()
    if ($_.Tags) { $have = @($_.Tags.PSObject.Properties.Name) }
    $miss = @($required | Where-Object { $_ -notin $have })

    if ($miss.Count -gt 0) {
        [pscustomobject]@{ Name=$_.Name; Type=($_.Type -split '/')[-1]; RG=$_.RG; Missing=($miss -join ',') }
    }
}

"{0} of {1} resources missing required tags" -f @($gaps).Count, @($all).Count
$gaps | Group-Object RG | Sort-Object Count -Descending | Select-Object Count, Name -First 10
```

```
312 of 847 resources missing required tags

Count Name
----- ----
   94 rg-legacy-migration          <-- ⚠⚠ nobody owns 94 resources
   61 rg-datasci-poc               <-- ⚠ the ungoverned subscription's RG
```

⭐ **Note the `@()` wrapping** — a single-result sweep silently reports nothing without it, the trap
from [`../../00-foundations/cli-and-scripting/`](../../00-foundations/cli-and-scripting/) §5.

**Then make it stop getting worse — inherit tags from the resource group with `Modify`:**

```bash
# ⭐ Built-in: "Inherit a tag from the resource group if missing"
az policy assignment create -n inherit-owner-tag \
  --policy /providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070 \
  --scope /subscriptions/<sub> --params '{"tagName":{"value":"Owner"}}' \
  --mi-system-assigned --location eastus --role Contributor --identity-scope /subscriptions/<sub>
```

⭐ **`Modify` needs a managed identity** — [`../azure-policy/`](../azure-policy/) §5, and that
identity is itself now an NHI in your inventory.

⚠ **`Modify` fixes new and remediated resources.** The 312 above need a **remediation task**;
assigning the policy does not touch them.

---

## 4. ⭐ The naming convention is a control

**A name is the one attribute that cannot be blank and is visible in every log line, alert and bill.**

```
rg-<workload>-<env>-<region>          rg-payments-prod-weu
<type>-<workload>-<env>-<nn>          vm-payments-prod-03
                        ▲
        ⭐ an alert on "vm-payments-prod-03" is already triaged
```

⭐ **Compare an alert on `vm-payments-prod-03` with one on `myVM2`.** The first tells you the
workload, the blast radius and the urgency before you open anything. **That is triage speed bought at
zero cost**, and it survives when tags are stripped, because ⚠ **a name cannot be empty and — unlike a
tag — cannot be silently changed** (renaming means recreating, which changes the resource ID:
[`../azure-resource-manager/`](../azure-resource-manager/) §5).

⚠ Enforce with a `Deny` policy on `name` patterns — but **audit first** and expect legacy exceptions.

---

## 5. What breaks

**Grouping by team instead of lifecycle.** §1 — the decommission finds out.

**Treating a resource group as isolation.** §1 — subscription rights reach in.

**Cross-group references nobody documented.** §1 — deleting a "spare" group breaks prod.

**Relying on a tag as a control.** §2 — ⭐ anyone with write can change it.

**Tags used in ABAC without a Deny on modification.** §2 — ⭐ a writable authorisation input.

**No `Owner` tag.** §2 — containment waits on finding a human.

**Assigning a `Modify` tag policy and assuming backfill.** §3 — remediation is separate.

**Forgetting `@()` in the sweep.** §3 — a single finding disappears.

**Names that carry no information.** §4 — every alert starts from zero.

**Resource group location confused with resource location.** §1 — data residency reviews get this
wrong in both directions.

---

## 6. Customer discovery questions

1. What is the rule for **what goes in a resource group** — lifecycle, or team? *(§1.)*
2. Are there **cross-group dependencies**, and are they documented?
3. Which tags are **required**, and how many resources are missing them? *(§3 — run it.)*
4. ⭐ At 02:00, can you identify the **owner** of any resource in under a minute? *(§2.)*
5. Is any tag used in an ⭐ **ABAC condition or policy** — and is it protected from modification?
6. Has a **remediation task** run, or was the tag policy just assigned? *(§3.)*
7. Does the **naming convention** encode workload and environment? *(§4.)*
8. Do people know a resource group's **location** is only metadata? *(§1.)*

---

## 7. Remember it

**Hook — "Group by lifecycle. Tag for the 2 a.m. question."**

**Analogy — labelled boxes in a shared warehouse.** ⭐ **A resource group is a pallet: everything on
it is collected and thrown out together**, so you put things on it that expire together, not things
that belong to the same department. ⭐ **Tags are the labels on the boxes — anyone with a marker can
change them, so they secure nothing** — but when the sprinklers go off at midnight, **the label is
the only reason you know which box to save first and whose it is.** No lock, enormous value.

**The one thing:** ⭐ **an `Owner` tag is an incident-response control, not a finance one.** Time to
contain is bounded by time to find a human who can authorise isolating the thing — and without
ownership metadata that is an hour of phoning people at night, during which the incident continues.
**Tags enforce nothing and shorten everything.**

**Runner-up:** ⭐ **a tag that feeds an ABAC condition is an authorisation input that anyone with
write access can edit** — protect it with a Deny policy or do not use it that way.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. What are the two properties of a resource group, and what grouping rule follows?
2. Is a resource group a security boundary?
3. What does a resource group's location actually store?
4. ⭐ Why can a tag never be a security control — and what is the one dangerous exception?
5. Which five tags earn their place, and what does each answer?
6. State the incident-response argument for tagging in one sentence.
7. Which policy effect backfills tags, what does it need, and what does it not do?
8. Why does `@()` matter in the tag-gap sweep?
9. Why is a naming convention more durable than a tag?
10. What happens to a resource's ID when it is renamed or moved?

<details>
<summary>Answers</summary>

1. ⭐ **Delete the group deletes the contents**, and it is an **RBAC/Policy scope**. Rule: ⭐ **group
   things that live and die together.**
2. ⚠ **No** — subscription-scoped rights reach into every group beneath it.
3. ⭐ Only the group's **metadata**; resources inside can live in other regions.
4. ⭐ **Anyone with write access to the resource can change it.** ⚠ Exception: tags read by **ABAC
   conditions or policies** become authorisation inputs — protect them with a Deny policy.
5. **Owner/OnCall** (who to wake), **Environment** (can I isolate), **DataClassification** (how bad),
   **CostCentre** (who pays), **ExpiresOn** (should this exist).
6. ⭐ **Time to contain is bounded by time to identify the owner.**
7. ⭐ **`Modify`.** It needs a **managed identity**, and it ⭐ **does not backfill existing
   resources** — that requires a remediation task.
8. ⭐ A single result is not an array, so `.Count` is `$null` and the finding silently disappears.
9. ⭐ A name **cannot be empty and cannot be silently changed** — renaming means recreating, which
   changes the resource ID.
10. ⭐ **It changes**, breaking role assignments, policy exemptions and monitoring rules bound to the
    old string.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 tag-gap sweep across the estate, plus the `Modify` policy and a remediation
  task. ✗ Requires an Azure subscription.
- **`break-fix/`** ⭐ — assign the tag-inheritance policy and show existing resources **still
  untagged**, then run remediation and show the difference. Then, as a Contributor, **change a tag
  that an ABAC condition depends on** and demonstrate the authorisation outcome changing. **That
  second one is the finding most people have never seen.**
- **`security/`** — required-tag definition and current coverage; resources with no owner; tags used
  in ABAC conditions and whether they are Deny-protected; naming convention conformance.
- **`operations/`** — incident runbook step: "identify owner from tags"; `ExpiresOn` review;
  cross-resource-group dependency register.
- **`architecture-decisions/`** — ADR: resource groups grouped by lifecycle; required tag set with the
  incident-response justification, not the finance one.
- **`customer-use-cases/`** — §6 answered; the "312 of 847 unowned" figure as the headline.

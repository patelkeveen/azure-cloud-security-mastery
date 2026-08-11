# Resource Locks

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **An anti-accident control, not a security control** — §2. Pairs with
> [`../azure-rbac/`](../azure-rbac/) and [`../azure-policy/`](../azure-policy/).

---

## 1. What it is

Two lock types, applied at management group, subscription, resource group or resource scope, and
⭐ **inherited downward** like everything else in
[`../subscriptions-and-management-groups/`](../subscriptions-and-management-groups/) §1.

| Lock | Blocks | Allows |
|---|---|---|
| **CanNotDelete** | delete | read, modify |
| ⭐ **ReadOnly** | ⭐ **delete *and* any write** | read only |

⭐ **`ReadOnly` is much stronger than people expect, and that is where the trouble starts** (§3).

---

## 2. ⭐ A lock is not a security control

> **Anyone with `Microsoft.Authorization/locks/*` can remove a lock — and Owner and User Access
> Administrator both have it.**

```
Attacker with Owner:   remove lock  →  delete resource     ⭐ two API calls
Engineer at 2 a.m.:    delete resource  →  BLOCKED         ⭐ locks work here
```

⭐ **So a lock defends against mistakes, not against adversaries or against a determined
administrator.** Presenting it as protection in a security review is a category error — the same one
as presenting a tag as a control ([`../resource-groups-and-tags/`](../resource-groups-and-tags/) §2).

**Where each layer actually sits:**

| Layer | Stops | ⭐ Defeated by |
|---|---|---|
| **Lock** | ⭐ accidents | anyone who can remove locks |
| **RBAC** | principals without the right | ⭐ someone always has Owner |
| ⭐ **Policy** | ⭐ **non-compliant shapes, including for Owners** | exemptions |
| **Deny assignment** | ⭐ **everyone, including Owner** | ⚠ only from Blueprints / managed apps |

⭐ **Read that column downward and you have the whole governance stack in one table** — and the answer
to "which layer does this control belong in?", which is the recurring architectural question of this
domain.

⚠ **Detect lock removal**, because it is a genuine pre-destruction signal:

```kusto
AzureActivity
| where OperationNameValue has "MICROSOFT.AUTHORIZATION/LOCKS/DELETE"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, CallerIpAddress, _ResourceId
```

⭐ **A lock removal immediately followed by a delete is a high-fidelity alert with almost no false
positives** — one of the better free detections in Azure, and it costs nothing beyond the Activity
Log you already have ([`../azure-resource-manager/`](../azure-resource-manager/) §3).

---

## 3. ⭐ ReadOnly breaks things you would not predict

**The trap: many "read" operations in Azure are `POST`, and `POST` counts as a write.**

```
⭐ List storage account keys      → POST → BLOCKED by ReadOnly
⭐ Get Cosmos DB connection string → POST → BLOCKED
   Restart a VM                   → POST → BLOCKED
   Backup / restore operations    → write → BLOCKED
   Add a child resource           → write → BLOCKED
```

⭐ **`ReadOnly` on a resource group containing a storage account can break every application that
retrieves keys at startup** — and the failure appears at the *application*, hours later, with an
authorization error that names the app rather than the lock. **It is a textbook invisible cause**
([`../../00-foundations/troubleshooting-method/`](../../00-foundations/troubleshooting-method/) §6).

> ⭐ **Default to `CanNotDelete`.** It covers the actual risk — accidental deletion — without the
> operational surface of `ReadOnly`. Reach for `ReadOnly` only when you genuinely mean *frozen*, and
> then expect to explain it to whoever is on call.

**And the deployment interaction:**

⭐ **A `CanNotDelete` lock inside a resource group makes a Complete-mode deployment fail** — because
Complete mode deletes what is not in the template ([`../azure-resource-manager/`](../azure-resource-manager/)
§4). ⚠ That is usually the lock doing its job, but it presents as a broken pipeline.

---

## 4. Worked example — audit what is protected and what is not

```powershell
# ① What locks exist, and where?
$locks = az lock list --query "[].{Name:name, Level:level, Scope:id}" -o json | ConvertFrom-Json
$locks | Sort-Object { $_.Scope.Length } | Format-Table -AutoSize
```

```
Name              Level          Scope
----------------  -------------  --------------------------------------------
prod-protect      CanNotDelete   /subscriptions/aaaa/resourceGroups/rg-prod
frozen-legacy     ReadOnly       /…/rg-legacy/providers/…/storageAccounts/stlegacy   <-- ⚠ see §3
```

```powershell
# ② ⭐ The inverse, and the real finding: which critical things have NO lock?
$critical = az resource list `
  --query "[?type=='Microsoft.KeyVault/vaults' || \
             type=='Microsoft.Storage/storageAccounts' || \
             type=='Microsoft.Sql/servers' || \
             type=='Microsoft.Network/expressRouteCircuits'].{Name:name, Type:type, Id:id}" `
  -o json | ConvertFrom-Json

$critical | Where-Object { $id = $_.Id; -not (@($locks | Where-Object { $id -like "$($_.Scope)*" })).Count } |
  Select-Object Name, @{n='Type';e={($_.Type -split '/')[-1]}}
```

```
Name           Type
-------------  ----------------
kv-prod-core   vaults              <-- ⚠⚠ deletable in one call
stprodbackups  storageAccounts     <-- ⚠⚠ the backups
```

⭐ **Row two is the classic.** The backup storage account is the thing you need *after* an incident,
and it is routinely the least protected — ⭐ **the recovery path is part of the attack surface.** An
adversary who can delete backups has converted a recoverable incident into an unrecoverable one, and
this query finds that in one line.

⭐ **Note the inverse framing.** Listing locks tells you what is protected; **listing critical
resources *without* locks tells you what is exposed.** The second is the report. This is the same
move as auditing write permissions rather than read permissions in
[`../../60-ai-and-secure-ai/data-poisoning/`](../../60-ai-and-secure-ai/data-poisoning/) §2 —
⭐ **look for the absence, not the presence.**

**Then apply, and prove:**

```bash
az lock create -n prod-nodelete --lock-type CanNotDelete \
  --resource-group rg-prod --resource-name stprodbackups \
  --resource-type Microsoft.Storage/storageAccounts

az storage account delete -n stprodbackups -g rg-prod --yes
```

```
Code: ScopeLocked
Message: The scope '/…/stprodbackups' cannot perform delete operation
         because following scope(s) are locked: '/…/stprodbackups'.
```

⭐ **`ScopeLocked` is the evidence string** — configuration becomes proof, exactly as
`RequestDisallowedByPolicy` does for Policy.

---

## 5. What breaks

**Presenting a lock as a security control.** §2 — ⭐ Owner removes it in one call.

**`ReadOnly` where `CanNotDelete` was meant.** §3 — ⭐ breaks key listing, restarts, backups.

**Not knowing that "list keys" is a POST.** §3 — the failure surfaces in the app, hours later.

**Locks inherited further than intended.** §1 — a subscription-scope lock reaches everything.

**Complete-mode deployment into a locked group.** §3 — a pipeline that fails correctly.

**No lock on backup storage.** §4 — ⭐ the recovery path is unprotected.

**Auditing locks instead of auditing gaps.** §4 — ⭐ look for the absence.

**No detection on lock deletion.** §2 — a high-fidelity signal left unused.

**Locks as a substitute for soft-delete / purge protection** on Key Vault — different mechanism,
different guarantee.

---

## 6. Customer discovery questions

1. What is locked, and ⭐ **what critical thing is not**? *(§4 — run the inverse query.)*
2. Is **backup storage** locked? *(§4.)*
3. Any `ReadOnly` locks — and does the team know they block key listing? *(§3.)*
4. Do you **alert on lock deletion**? *(§2.)*
5. Is a lock being presented as protection **against an attacker**? *(§2.)*
6. Does any pipeline deploy **Complete mode** into a locked scope?
7. Is Key Vault **purge protection** on, separately from any lock?
8. Who can remove locks, and is that the same list as Owner?

---

## 7. Remember it

**Hook — "Locks stop fingers, not adversaries."**

**Analogy — the plastic cover over the big red button.** ⭐ **It exists so nobody elbows the button by
accident**, and it works perfectly for that. **It is not a defence against someone who wants to press
it** — they lift the cover. ⭐ **And `ReadOnly` is welding the whole panel shut**: nothing gets pressed
by accident, and also nobody can read the dials, because in Azure reading the dials is often a
`POST`.

**The one thing:** ⭐ **audit for the absence, not the presence.** A list of locks tells you what
somebody remembered to protect; the useful report is **critical resources with no lock** — and the
row that shows up is almost always the **backup storage account**. An adversary who deletes backups
turns a recoverable incident into an unrecoverable one, so ⭐ **the recovery path is part of the attack
surface**, and it is the part nobody hardens because it is not serving traffic.

**Runner-up:** ⭐ **`ReadOnly` blocks listing storage keys, because that is a `POST`.** Default to
`CanNotDelete`.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. Name the two lock types and exactly what each blocks.
2. ⭐ Why is a lock not a security control? Who can remove one?
3. Place lock, RBAC, Policy and deny assignment in order of who they stop.
4. ⭐ Name three operations `ReadOnly` blocks that people expect to work, and why.
5. Which lock type should be the default, and why?
6. What happens to a Complete-mode deployment in a locked resource group?
7. ⭐ What is the more useful audit: locks present, or locks absent? Give the classic finding.
8. What error string proves a lock is working?
9. What detection should exist around locks, and why is it high fidelity?
10. Which Key Vault feature is a separate guarantee from a lock?

<details>
<summary>Answers</summary>

1. **CanNotDelete** blocks delete only. ⭐ **ReadOnly** blocks **delete and every write**.
2. ⭐ Anyone with **`Microsoft.Authorization/locks/*`** can remove it — including **Owner** and **User
   Access Administrator**. It defends against **accidents**.
3. **Lock** → accidents; **RBAC** → principals without the right; ⭐ **Policy** → non-compliant shapes
   *including for Owners*; ⭐ **deny assignment** → everyone including Owner (⚠ only from Blueprints /
   managed apps).
4. ⭐ **Listing storage keys, getting a Cosmos connection string, restarting a VM** — they are
   **`POST` operations**, which count as writes.
5. ⭐ **CanNotDelete** — it covers the real risk without `ReadOnly`'s operational surface.
6. ⚠ It **fails**, because Complete mode deletes what is not in the template. Usually the lock working
   correctly.
7. ⭐ **Absent.** The classic finding is ⭐ **backup storage with no lock** — the recovery path is part
   of the attack surface.
8. ⭐ **`ScopeLocked`.**
9. ⭐ **Alert on lock deletion**, especially followed by a delete — near-zero false positives and it
   precedes destruction.
10. ⭐ **Purge protection** (with soft delete) — a different mechanism and a different guarantee.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** — the §4 lock inventory, the inverse gap query, and the `ScopeLocked` proof. ✗ Requires
  an Azure subscription.
- **`break-fix/`** ⭐ — apply a **`ReadOnly`** lock to a resource group containing a storage account,
  then watch an application that lists keys at startup fail — **and time how long it takes to connect
  the failure to the lock.** That delay is the lesson. Then swap to `CanNotDelete` and show it
  recover.
- **`security/`** — critical resources with no lock (especially backups); lock-deletion detection
  deployed; who holds lock-management rights.
- **`operations/`** — lock as a step in the go-live checklist; documented procedure for temporary lock
  removal with re-application, and an alert that fires if it is not re-applied.
- **`architecture-decisions/`** — ADR: `CanNotDelete` by default, `ReadOnly` only by exception with a
  named owner; ⭐ backups locked and purge-protected as a recovery-path requirement.
- **`customer-use-cases/`** — §6 answered; "your backups are deletable in one call" as the headline
  finding.

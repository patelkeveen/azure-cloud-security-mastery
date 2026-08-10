# Entra Users and Groups

> **Concept facet.** Full depth in
> **[LAYER-2-DOMAIN-1-USER-IDENTITIES.md](LAYER-2-DOMAIN-1-USER-IDENTITIES.md)** in this folder.
> Lab seeder: **[Seed-LabTenant.ps1](Seed-LabTenant.ps1)**.

## What it is

The directory objects everything else attaches to. Get the object model wrong and every downstream
control — Conditional Access assignment, licence allocation, access review scope — inherits the
error.

## The concept that explains half the tickets: source of authority

| Source | Edited where | Consequence |
|---|---|---|
| **Cloud** | Entra | Fully editable |
| **Windows Server AD** | On-premises | **Most attributes read-only in Entra** |
| **External / B2B** | Partner's home tenant | You hold a stub; they own the credential |

A synced user showing greyed-out fields is not broken. Entra is refusing to create a divergence it
cannot reconcile. **Half of all "why can't I change this?" questions are a source-of-authority
answer.**

## Users — the fields that bite

- **`UserPrincipalName` ≠ `mail` ≠ `proxyAddresses`.** Sign-in uses UPN; mail routing uses
  proxyAddresses. They frequently differ, and assuming they match produces "can't sign in but
  receives email fine."
- **`UsageLocation` is mandatory before licensing** — and the error does not say so.
- **Soft delete is 30 days.** `Get-MgDirectoryDeletedItemAsUser` is the first move in any
  "I deleted the wrong account" incident. Restore preserves the `oid`; recreation does not, which
  is why restore works and recreate silently breaks every prior grant.
- **`oid` is the only stable identifier.** UPNs change; guests are `#EXT#`-mangled. **Correlate on
  `oid`** — in KQL, in scripts, everywhere.

## Groups

| | Security group | M365 group |
|---|---|---|
| Purpose | Access control | Collaboration (mailbox, site, Teams) |
| Nesting | Yes | **No** |
| Has a mailbox | No | Yes |

**Dynamic membership** deserves more respect than it gets:

```
(user.department -eq "Engineering")
(user.department -eq "Sales") -and (user.country -eq "India")
(user.extensionAttribute1 -startsWith "CONTRACTOR")
```

Four things bite people: evaluation is **asynchronous** (minutes at small scale, far longer at
tens of thousands — check processing state before debugging syntax); you **cannot manually add or
remove members**, the rule is the only authority; it requires **P1**; and a perfect rule over an
**unpopulated attribute** returns an empty group, which in hybrid environments is a *sync* problem
wearing a *groups* costume.

**Role-assignable groups must be created with `isAssignableToRole = true` at creation time and it
can never be changed.** Discovering that after building the group structure is a painful afternoon.

## Group-based licensing

Elegant, with sharp edges: conflicts when two licences grant the same service plan; **removing a
user from the group removes the licence**, which deletes service data after the grace period. An
offboarding automation that drops group membership is also deleting mailboxes.

## The traps

1. Assuming UPN and mail match.
2. Debugging dynamic-group *syntax* when the problem is evaluation latency or an empty attribute.
3. Deleting instead of restoring — losing the `oid` and every grant tied to it.
4. Forgetting `UsageLocation` and misreading the licensing error.

## Evidence this topic needs

- `lab/` — run `Seed-LabTenant.ps1`; create a dynamic group and **time** the membership update.
- `break-fix/` — delete a user, recover from soft delete, prove the `oid` is unchanged.
- `operations/` — bulk operations with server-side `-Filter`, throttling backoff, idempotency.

# Source Anchor and Object Matching

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (doc last updated 2026-08-09).
> **Contains a behaviour change effective 1 July 2026 that most published material predates.**
> Prerequisite: [`../entra-connect-sync/`](../entra-connect-sync/).

---

## 1. What it is

The **source anchor** is the immutable value that ties one on-premises AD object to one Entra ID
object, permanently. **Matching** is the decision Entra ID makes when a synced object arrives:
*is this somebody I already know, or somebody new?*

Get it right and nobody notices. Get it wrong and you produce two accounts per human, a mailbox
nobody can open, and a migration that has to be unwound by hand.

---

## 2. Why it exists

`displayName` changes at marriage. `userPrincipalName` changes at rebrand. `sAMAccountName`
changes at merger. Every human-readable identifier is mutable, so none can be the join key.

The system needs a value that:

- never changes for the lifetime of the identity,
- is not reused,
- survives a forest migration.

`objectGUID` satisfies the first two and **fails the third** — it is assigned by the domain, so
moving a user to a new forest mints a new one. That single fact is why `ms-DS-ConsistencyGuid`
exists.

---

## 3. How it works underneath

### The two candidate anchors

| | `objectGUID` | `ms-DS-ConsistencyGuid` |
|---|---|---|
| Set by | The domain, at creation | **Connect writes it** on first sync |
| Survives forest migration | ❌ **No** | ✅ Yes — you carry the value across |
| Default in current Connect | ❌ | ✅ **Yes** |
| Editable | No | Yes (it is a normal writable attribute) |

Default behaviour: Connect reads `ms-DS-ConsistencyGuid`; if it is empty, it **copies
`objectGUID` into it** and uses that from then on. After that, the anchor is a value you control
rather than one the domain controls — which is the whole point.

> **If a customer is anchored on `objectGUID`, that is a migration blocker, not a preference.**
> Any forest consolidation re-creates every single user in Entra ID as a brand-new object:
> new mailbox, lost OneDrive, lost group membership, lost licence assignment.

### The three matching attributes

Only three attributes are ever consulted:

| Attribute | Match type |
|---|---|
| `sourceAnchor` → `immutableId` | **Hard match** |
| `userPrincipalName` | **Soft match** |
| `proxyAddresses` — **only the `SMTP:` primary**, not `smtp:` aliases | **Soft match** |

### Order of evaluation

```
New object arrives from on-prem AD
        │
        ▼
  Does immutableId match an existing cloud object?
        │
   yes ─┴─ no
    │       │
    ▼       ▼
 HARD    Does UPN or primary SMTP match?
 MATCH        │
    │    yes ─┴─ no
    │     │       │
    │     ▼       ▼
    │   SOFT   PROVISION
    │   MATCH   new object
    │     │
    └─────┴──► SOURCE OF AUTHORITY moves on-premises.
               Cloud values are OVERWRITTEN by AD values.
```

**Two rules people miss:**

1. **Matching is evaluated only for *new* objects arriving from AD.** Editing an existing object
   so that it happens to match something does not trigger a match — it triggers an error.
2. **After a soft match succeeds, Entra ID stamps the `sourceAnchor` onto the cloud object**, so
   every subsequent sync is a hard match. Soft match is a one-time bootstrap, not a steady state.

### The overwrite that eats data

> On a successful match, **every Entra ID attribute that has a value on-premises is overwritten
> with the on-premises value.**

If the business maintained job titles, phone numbers, or manager chains in Microsoft 365 for three
years while AD sat stale, **that data is gone at the first sync.** ✅ verified.

The fix is boring and mandatory: export the cloud attributes, reconcile them into AD, *then*
enable sync. Skipping it is the most expensive mistake in hybrid onboarding, and it is not
recoverable from the sync engine.

---

## 4. Worked example

`Priya Raman` already exists as a cloud-only user, created during a pilot. IT now builds her AD
account and enables sync.

**Cloud object before:**

```
userPrincipalName      : priya.raman@contoso.com
proxyAddresses         : SMTP:priya.raman@contoso.com
jobTitle               : Head of Financial Planning     <-- maintained in M365 only
onPremisesSyncEnabled  : false
onPremisesImmutableId  : (null)
```

**Incoming AD object:**

```
objectGUID             : a1b2c3d4-e5f6-4789-abcd-1234567890ab
userPrincipalName      : priya.raman@contoso.com
proxyAddresses         : SMTP:priya.raman@contoso.com
title                  : (empty)                        <-- nobody filled this in AD
```

**What happens:**

1. `immutableId` is null on the cloud object → no hard match.
2. UPN matches → **soft match**.
3. Source of authority moves on-premises.
4. `ms-DS-ConsistencyGuid` is written in AD, and its Base64 form is stamped as `immutableId`:

```powershell
$g = [guid]'a1b2c3d4-e5f6-4789-abcd-1234567890ab'
[Convert]::ToBase64String($g.ToByteArray())    # 1MOyofbliUerzRI0VniQqw==
```

5. **`jobTitle` is overwritten with empty.** "Head of Financial Planning" is gone from Entra ID,
   from the M365 profile card, and from the org chart.

Nobody gets an alert. It shows up weeks later as "why is the directory blank?"

**Verify the anchor landed:**

```powershell
Get-MgUser -UserId priya.raman@contoso.com `
  -Property UserPrincipalName,OnPremisesSyncEnabled,OnPremisesImmutableId,OnPremisesObjectIdentifier |
  Format-List
```

```
UserPrincipalName          : priya.raman@contoso.com
OnPremisesSyncEnabled      : True
OnPremisesImmutableId      : 1MOyofbliUerzRI0VniQqw==
OnPremisesObjectIdentifier : a1b2c3d4-e5f6-4789-abcd-1234567890ab
```

---

## 5. ⚠ NEW — hard match protections, effective 1 July 2026

✅ Verified 2026-08-10. **This postdates most training material in circulation, including most
SC-300 courses.** Knowing it is a live differentiator.

Entra ID now **blocks** a hard match when the target cloud account:

- already has **`onPremisesObjectIdentifier`** set, **or**
- is **assigned** a privileged Entra role, **or**
- is **eligible** for a privileged Entra role (PIM eligibility counts).

**Why this shipped.** Hard match was a privilege-escalation path: anyone who could create an AD
object and set `ms-DS-ConsistencyGuid` could take over a Global Administrator's cloud account and
inherit its roles. The check is enforced **in the cloud**, so it applies to Connect Sync *and*
Cloud Sync regardless of client version — you cannot dodge it by downgrading the agent.

Hard match is not disabled. Safe targets still match, and already-matched users are unaffected.

| Scenario | Result | Recovery |
|---|---|---|
| New AD user → non-privileged, unmapped cloud user | ✅ Continues | None needed |
| Target has a privileged role **assigned** | ❌ Blocked | Remove role → match → reassign |
| Target is **eligible** for a privileged role | ❌ Blocked | Remove eligibility → match → restore |
| Target is soft-deleted **and** privileged | ❌ Blocked | Restore from recycle bin, then as above |
| Target already has `onPremisesObjectIdentifier` (AD user recreated, forest move, merger) | ❌ `AttributeUpdateNotAllowed` | Clear it to `null`, re-sync |
| Cannot remediate before enforcement | ⚠ Bypass | `allowOnPremUpdateOfOnPremisesObjectIdentifierEnabled` |

**Clear a stale `onPremisesObjectIdentifier`** — it can only be set to `null`, never to another
value. Requires `User-OnPremisesSyncBehavior.ReadWrite.All` plus Global Admin or Hybrid Identity
Administrator:

```http
PATCH https://graph.microsoft.com/beta/users/{userId}
Content-Type: application/json

{ "onPremisesObjectIdentifier": null }
```

Or with ADSyncTools **2.5.0 or later** — take the backup, it is one line:

```powershell
Import-Module ADSyncTools -MinimumVersion 2.5
Get-ADSyncToolsOnPremisesAttribute -Id $userId | Export-Clixml backupOnpremisesAttributes.Clixml
Clear-ADSyncToolsOnPremisesAttribute -Id $userId -onPremisesObjectIdentifier
```

The temporary bypass flag exists and should be treated as a fire door — on for the migration
window, off immediately after:

```powershell
Connect-MgGraph -Scopes "OnPremDirectorySynchronization.ReadWrite.All"
$s = Get-MgDirectoryOnPremiseSynchronization
$s.Features.AllowOnPremUpdateOfOnPremisesObjectIdentifierEnabled = $true
Update-MgDirectoryOnPremiseSynchronization -OnPremisesDirectorySynchronizationId $s.Id -Features $s.Features
```

---

## 6. The two block flags — read these in every tenant review

```powershell
Connect-MgGraph -Scopes 'OnPremDirectorySynchronization.ReadWrite.All'
(Get-MgDirectoryOnPremiseSynchronization).Features |
  Select-Object BlockSoftMatchEnabled, BlockCloudObjectTakeoverThroughHardMatchEnabled
```

```
BlockSoftMatchEnabled                           : False
BlockCloudObjectTakeoverThroughHardMatchEnabled : False
```

**Microsoft's own guidance is to enable both unless you are actively taking over cloud accounts.**
Defaults are `False` because matching has to work during onboarding. Most tenants never turn them
back on afterwards, and the matching path stays open forever.

The correct operating posture:

```
both True  ──►  migration window: set to False  ──►  matching done: set back to True
```

Turning them on is a two-minute change and closes a real takeover path. It is one of the highest
value-per-effort recommendations you can make in a tenant review.

---

## 7. What breaks, and the actual errors

**`AttributeValueMustBeUnique`** — the headline error. Read the `AttributeConflictName`:

| `AttributeConflictName` | Meaning |
|---|---|
| `ProxyAddresses` | Incoming object has a different sourceAnchor **and** different SID, but the same primary SMTP as an existing cloud user |
| `OnPremiseSecurityIdentifier` | Different sourceAnchor, but the **same SID** and primary SMTP |

Usual cause: you are re-provisioning the same human — the AD account was deleted and recreated, so
it carries a new GUID. **Fix it in AD, not in the cloud:** set `ms-DS-ConsistencyGuid` on the
on-premises user to the existing cloud user's `immutableId`, then re-sync. That converts the
failing provision into a correct hard match.

> A rare variant: `OnPremiseSecurityIdentifier` conflicts caused by an **AD RID pool problem** —
> classically a DC restored from backup issuing SIDs that were already handed out. That is not a
> sync fault at all, and chasing it in Connect wastes days. Symptom to recognise: duplicate SIDs
> on objects that were never related.

---

**Admin accounts silently refuse to soft match.** By design, Entra ID will not soft match an
on-premises user to a cloud user holding a directory role. A quarantined object appears instead.
Recovery: remove the roles, **hard-delete** the quarantined object, re-sync, then re-add the roles.

> Microsoft states plainly: **do not sync on-premises accounts onto pre-existing administrative
> accounts.** Cloud-only, phishing-resistant break-glass accounts stay cloud-only.

---

**Groups behave differently and it is not documented where people look:**

| Object | Soft match | Hard match |
|---|---|---|
| User | ✅ UPN / primary SMTP | ✅ sourceAnchor |
| Mail-enabled group, contact | ✅ proxyAddresses | ❌ — sourceAnchor is only settable on users |
| **Non-mail-enabled group** | ❌ **None** | ❌ **None** |

**A security group that already exists in the cloud will always be duplicated**, never matched.
Plan for it; it surprises people mid-cutover.

---

## 8. Customer discovery questions

1. Is the anchor `ms-DS-ConsistencyGuid` or `objectGUID`? *(If `objectGUID` — flag it before any
   forest work is scoped.)*
2. Are `BlockSoftMatchEnabled` and `BlockCloudObjectTakeoverThroughHardMatchEnabled` `True`?
   If `False`, was a migration ever completed and simply never closed out?
3. Was any attribute maintained **only** in M365 before sync was enabled? *(§3 data-loss check.)*
4. Are any privileged cloud accounts synced from on-premises? *(They should not be, and since
   1 July 2026 hard-matching them is blocked anyway.)*
5. Any `AttributeValueMustBeUnique` errors currently outstanding, and for how long?
6. Any forest consolidation, divestiture, or acquisition planned in 24 months? *(Decides whether
   question 1 is urgent or merely wrong.)*

---

## 9. Remember it

**Hook — "Hard before soft"** (sourceAnchor is tried first, then UPN/SMTP), and
**"GUID dies at the forest border; ConsistencyGuid crosses it."**

**Analogy — a passport number, not a national ID.** Names change with marriage, rebrand, merger.
`objectGUID` is a national ID: worthless once you emigrate to a new forest. `ms-DS-ConsistencyGuid`
is a number **you** control and carry across the border.

**The one thing:** the first three GUID fields are **little-endian**. Every hand-rolled immutableId
script that concatenates hex in display order produces a wrong value, fails the hard match, and
silently duplicates the user.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 10. Self-test

1. Which three attributes are used for matching, and which produce a hard versus a soft match?
2. Why does `ms-DS-ConsistencyGuid` exist when `objectGUID` is already immutable?
3. A cloud-only user has a job title maintained in M365 but not in AD. Sync is enabled and soft
   match succeeds. What is the title afterwards?
4. Since 1 July 2026, why might a hard match against a Global Administrator's account fail?
5. `AttributeValueMustBeUnique` with `AttributeConflictName = ProxyAddresses`. What did you do?
6. Why can a non-mail-enabled security group never be matched?
7. Both block flags are `False` in a tenant that finished migrating in 2023. What do you recommend?
8. Only an alias `smtp:` address matches — does a soft match occur?

<details>
<summary>Answers</summary>

1. `sourceAnchor`/`immutableId` → **hard**. `userPrincipalName` and `proxyAddresses` (primary
   `SMTP:` only) → **soft**.
2. `objectGUID` is assigned by the domain, so it **does not survive a forest migration**.
   `ms-DS-ConsistencyGuid` is writable, so you carry the value across.
3. **Empty.** Every Entra attribute with an on-premises counterpart is overwritten by the AD value,
   including with a blank. Unrecoverable from the sync engine.
4. Hard match is blocked when the target is assigned **or eligible for** a privileged role, or
   already has `onPremisesObjectIdentifier` set. Enforced in the cloud, so client version is irrelevant.
5. Almost certainly re-provisioned the same human with a new GUID. Set `ms-DS-ConsistencyGuid`
   on-premises to the cloud user's `immutableId` and re-sync.
6. Soft and hard match are **not supported** for non-mail-enabled groups. It will duplicate.
7. Set both to `True`. Migration is long finished; the takeover path is open for no reason.
8. **No.** Only the primary `SMTP:` value is evaluated. Lowercase `smtp:` aliases are ignored.

</details>

---

## 11. Evidence this topic needs

- **`lab/`** — create a cloud-only user, then an AD user with the same UPN; watch the soft match
  take over and confirm `OnPremisesImmutableId` gets stamped. Then set a job title in the cloud
  only and prove it is erased.
- **`break-fix/`** — force `AttributeValueMustBeUnique` by recreating an AD account; capture the
  error verbatim; repair it by writing `ms-DS-ConsistencyGuid`.
- **`security/`** — both block flags with a written rationale; an inventory of any synced
  privileged accounts; the §5 protections tested against a role-holding target.
- **`operations/`** — the "open the flags for migration, close them after" runbook, with the
  closing step assigned to a named owner and a date.
- **`architecture-decisions/`** — ADR: anchor choice, and its consequences for a future forest merge.
- **`customer-use-cases/`** — §8 answered against a real estate.

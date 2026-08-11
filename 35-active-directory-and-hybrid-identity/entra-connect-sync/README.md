# Entra Connect Sync

> **Reference implementation for [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).**
> Verified against Microsoft Learn **2026-08-10**. SC-300 Domain 1. Also the single most common
> "explain how this actually works" question in a Microsoft identity interview.

---

## 1. What it is

A **metadirectory synchronization engine** that runs on a Windows server you own, reads objects
from on-premises Active Directory, and writes a projection of them into Entra ID.

It is not a replication service and it is not a copy. It is a **three-stage pipeline with an
intermediate model** — and every non-obvious behaviour you will ever debug comes from that
intermediate model existing.

---

## 2. Why it exists

Before it, an organisation adopting a cloud service had two options, both bad:

| Option | What it cost |
|---|---|
| Create every user again in the cloud | Two identities per human. Two passwords. Two joiner/leaver processes. A leaver disabled on-premises still has a live cloud account — this is how ex-employees keep mailbox access for years. |
| Federate everything to AD FS | A server farm on the critical path of every single sign-in. If AD FS is down, **nobody authenticates to anything.** |

Connect Sync makes AD the **authoritative source** and Entra ID a **derived replica**, so the
joiner/mover/leaver process you already have keeps working and reaches the cloud automatically.

**Directionally, the default is one-way: AD → Entra ID.** Writeback (passwords, devices, groups)
is opt-in and each kind is configured separately. Assume nothing flows back unless you verified
it does.

---

## 3. How it works underneath

The engine is the old Microsoft Identity Manager sync core. Three storage areas, not two:

```
   ON-PREM AD                                                    ENTRA ID
   (connected system)                                       (connected system)
        │                                                            ▲
        │  ①  IMPORT                                      ⑤ EXPORT   │
        ▼     (delta or full)                                        │
┌──────────────────┐                                    ┌──────────────────┐
│  CONNECTOR SPACE │                                    │  CONNECTOR SPACE │
│      (AD)        │                                    │    (Entra ID)    │
│  staging copy of │                                    │  staging copy of │
│  what AD looks   │                                    │  what Entra      │
│  like            │                                    │  should look like│
└──────────────────┘                                    └──────────────────┘
        │                                                            ▲
        │  ②  INBOUND SYNC RULES (ISR)      ④ OUTBOUND SYNC RULES (OSR)
        │      attribute flow                       attribute flow    │
        ▼                                                            │
      ┌────────────────────────────────────────────────────────┐
      │                      METAVERSE                          │
      │  ③  ONE object per human, assembled from all sources.    │
      │     Cannot be edited directly — only fed by flows.       │
      └────────────────────────────────────────────────────────┘
```

**Why the connector space exists at all.** It decouples "talking to the directory" from
"deciding what the truth is." Import and export happen **only when scheduled**, so a change in AD
does not propagate automatically — it lands in the connector space and waits. That is what makes
staging mode and preview possible, and it is why a change you made in AD 20 seconds ago is not in
Entra ID yet.

**Why the metaverse exists.** It is the consolidated view of one identity assembled from every
source. Objects appear there when an authoritative connector **projects** them, and the metaverse
object is deleted the moment its last connection is removed.

Two operations people confuse constantly:

| Operation | Meaning |
|---|---|
| **Project** | An authoritative source creates a *new* metaverse object. "This human is new to me." |
| **Join** | An existing metaverse object is *linked* to an existing connector-space object. "I already know this human from elsewhere." |
| **Provision** | A metaverse object causes a *new* connector-space object downstream — which does nothing to the real directory **until export runs**. |

> **The join rule is evaluated once.** After the link exists, it is never re-evaluated. This is
> why a bad join is not self-healing and why fixing a mismatched account requires explicitly
> disconnecting it.

---

## 4. Worked example — one user through the whole pipeline

`Priya Raman` is created in `corp.contoso.com`.

**Stage ① — Import.** The AD connector reads her over LDAP into the AD connector space:

```
distinguishedName : CN=Priya Raman,OU=Staff,DC=corp,DC=contoso,DC=com
objectGUID        : a1b2c3d4-e5f6-4789-abcd-1234567890ab
sAMAccountName    : praman
userPrincipalName : praman@corp.contoso.com
mail              : priya.raman@contoso.com
proxyAddresses    : SMTP:priya.raman@contoso.com
department        : Finance
accountExpires    : 133700000000000000
```

Nothing has reached Entra ID. This is a staging copy.

**Stage ② — Inbound sync rules** flow attributes into a metaverse object, transforming as they go.
The rule `In from AD - User Common` does roughly this:

```
sourceAnchorBinary  ← ms-DS-ConsistencyGuid  (falls back to objectGUID if empty)
accountEnabled      ← NOT(userAccountControl BITAND 0x2)
displayName         ← displayName
department          ← department
```

**Stage ③ — The metaverse object** now holds the assembled identity. Note what did *not* arrive:

> **`accountExpires` is not synchronized to Entra ID.** ✅ verified 2026-08-10.
> An AD account that expired last night is **still active in Entra ID** and can still open the
> mailbox. If a customer uses `accountExpires` for contractors — and many do — this is a live
> access-control hole. The mitigation is a scheduled task that runs `Disable-ADAccount` on expiry.
> **This is a finding you can hand a customer in week one.**

**Stage ④ — Outbound sync rules** flow to the Entra connector space, where `sourceAnchor` becomes
the immutable ID:

```
objectGUID    a1b2c3d4-e5f6-4789-abcd-1234567890ab
              ↓  .NET Guid.ToByteArray()  — first three fields are LITTLE-ENDIAN
bytes         d4 c3 b2 a1  f6 e5  89 47  ab cd 12 34 56 78 90 ab
              ↓  Base64
immutableId   1MOyofbliUerzRI0VniQqw==
```

Reproduce it yourself — ✅ verified, this is real output:

```powershell
$g = [guid]'a1b2c3d4-e5f6-4789-abcd-1234567890ab'
[Convert]::ToBase64String($g.ToByteArray())      # 1MOyofbliUerzRI0VniQqw==
[guid]([Convert]::FromBase64String('1MOyofbliUerzRI0VniQqw=='))   # round-trips
```

> **Look at the byte order.** `a1b2c3d4` became `d4 c3 b2 a1`. Three fields of a GUID are stored
> little-endian; the last eight bytes are not. **Every hand-rolled immutableId script that
> concatenates the hex string in display order produces a wrong value**, the hard-match fails, and
> a duplicate account is created instead. If you only remember one thing from this topic, this is it.

**Stage ⑤ — Export.** Only now does anything change in Entra ID.

---

## 5. Commands, with expected output

**What the scheduler is actually doing** — run this before believing any documentation:

```powershell
Get-ADSyncScheduler
```

```
AllowedSyncCycleInterval            : 00:30:00
CurrentlyEffectiveSyncCycleInterval : 00:30:00
CustomizedSyncCycleInterval         :
NextSyncCyclePolicyType             : Delta
NextSyncCycleStartTimeInUTC         : 2026-08-10 14:30:11
PurgeRunHistoryInterval             : 7.00:00:00
SyncCycleEnabled                    : True
StagingModeEnabled                  : False
```

Read three fields: `SyncCycleEnabled` (is it running at all), `StagingModeEnabled` (is this server
actually exporting, or just watching), and `CurrentlyEffectiveSyncCycleInterval`. **30 minutes is
the floor as well as the default** — Microsoft does not support running it faster.

**Force a cycle:**

```powershell
Start-ADSyncSyncCycle -PolicyType Delta      # changes only — normal
Start-ADSyncSyncCycle -PolicyType Initial    # full re-evaluation — hours on a large estate
```

`Initial` re-reads and re-evaluates *everything*. On a 100,000-object directory that is a
multi-hour operation that also re-exports. Do not run it to "make sure" during business hours.

**Confirm the tenant's view of sync — runs from anywhere, no on-prem access needed:**

```powershell
Connect-MgGraph -Scopes 'Organization.Read.All'
Get-MgOrganization | Select-Object -ExpandProperty OnPremisesSyncEnabled       # True
(Get-MgDirectoryOnPremiseSynchronization).Features
```

```
BlockCloudObjectTakeoverThroughHardMatchEnabled : True
BlockSoftMatchEnabled                           : False
CloudPasswordPolicyForPasswordSyncedUsersEnabled: False
UserForcePasswordChangeOnLogonEnabled           : False
```

Those four booleans are a **security review in themselves** — see §7.

**Is a given user cloud-only or synced?**

```powershell
Get-MgUser -UserId praman@contoso.com -Property OnPremisesSyncEnabled,OnPremisesImmutableId,UserPrincipalName |
  Select-Object UserPrincipalName, OnPremisesSyncEnabled, OnPremisesImmutableId
```

`OnPremisesSyncEnabled = True` means **the object is read-only in the cloud**. Attempts to edit
it in the portal fail, and that surprises administrators constantly.

---

## 6. Password hash synchronization, byte by byte

The most misunderstood feature in Microsoft identity. People refuse it because "we don't want our
passwords in the cloud." **No password, and no usable password hash, ever leaves the building.**
Here is the actual algorithm — ✅ verified against Microsoft Learn 2026-08-10:

```
1.  Every 2 MINUTES the PHS agent requests unicodePwd from a DC
      └ over MS-DRSR, the same protocol DCs use with each other
      └ requires "Replicate Directory Changes" + "Replicate Directory Changes All"
2.  DC encrypts the MD4 hash with a key derived from the RPC session key + salt
3.  Agent decrypts with MD5 → back to the raw 16-byte MD4 hash
      └ MD5 is used ONLY for on-prem RPC compatibility, not for protection
4.  16 bytes → 32-char hex string → re-encoded UTF-16 → 64 bytes
5.  + a 10-byte per-user salt
6.  → PBKDF2, 1,000 iterations, HMAC-SHA256
7.  Resulting 32-byte hash + salt + iteration count → TLS → Entra ID
```

> **The MD4 hash is never transmitted.** What Entra ID stores is a salted SHA256 derivative of it.
> Steal the cloud hash and you **cannot** pass-the-hash against on-premises AD. That single
> sentence is the answer to the customer objection, and it is why PHS is more secure than the thing
> the customer is already doing.

**Two-minute cadence, independent of the 30-minute object sync.** A password changed at 09:00
usually works in the cloud by 09:02, while a department change waits for the next half-hour cycle.
Users notice this asymmetry and report it as a bug.

**The expiry trap.** By default `CloudPasswordPolicyForPasswordSyncedUsersEnabled = False`, so
Connect stamps `DisablePasswordExpiration` on every synced user at every password sync. Result:
**on-premises expiry policy is not enforced in the cloud.** Enable the feature *before* enabling
PHS — retrofitting only clears the flag on each user's *next* password change.

**SCRIL users.** With "Smart Card Required for Interactive Logon", the DC randomises the AD
password, and that randomised hash syncs — which is what you want. Re-enabling SCRIL after a lost
card needs Connect **2.4.18.0 or later**, or the user's old password keeps working in the cloud.

---

## 7. When and where

| Situation | Use |
|---|---|
| Single AD forest, standard estate | **Cloud Sync** ([`../entra-cloud-sync/`](../entra-cloud-sync/)) — lightweight agent, no server, HA by default |
| **Hybrid Entra join (device sync)**, >150k objects/domain, groups >50k members, advanced sync rules, cross-forest references | **Connect Sync** — still the only option |
| Merger, **disconnected** forests | **Cloud Sync** — Connect Sync does **not** support disconnected forests |

> **Exchange hybrid attributes are supported by *both*** ✅ verified 2026-08-10 — a common and
> costly misconception that pushes customers onto Connect Sync unnecessarily. The genuine
> Connect-only blockers are the four in row two. Full table in
> [`../entra-cloud-sync/`](../entra-cloud-sync/).
| Existing AD FS estate | Both — PHS as the [fallback](../adfs-and-federation/) when the farm is down |

**Default recommendation in 2026 is Cloud Sync unless a Connect-only feature is required.**
Leading with Connect Sync out of habit is the sign of someone who stopped reading in 2019.

**Sizing:** ⚠ check against the current sizing table before quoting — SQL Express caps around
**100,000 objects**, above which a full SQL Server is required.

---

## 8. What breaks, and the actual errors

**`Unable to update this object because the following attributes associated with this object have
values that may already be associated with another object in your local directory services`**

A **duplicate attribute conflict** — usually `proxyAddresses` or `userPrincipalName` already used
by a different cloud object. Diagnosis: find the conflicting object with

```powershell
Get-MgUser -Filter "proxyAddresses/any(p:p eq 'SMTP:priya.raman@contoso.com')" -ConsistencyLevel eventual -CountVariable c
```

Fix the data in AD, not in the cloud. The cloud object is read-only.

---

**Two accounts for one human after a migration.** Soft match matched on `userPrincipalName` /
`primary SMTP`, or it failed to. Note that **`BlockSoftMatchEnabled` defaults to `False`** — soft
match is on. That is convenient and it is also how an attacker with the ability to create an AD
object can take over an existing cloud identity. In a hardened tenant, both
`BlockSoftMatchEnabled` and `BlockCloudObjectTakeoverThroughHardMatchEnabled` are `True`, and are
turned off only for the duration of a planned migration window. See
[`../source-anchor-and-matching/`](../source-anchor-and-matching/).

---

**`stopped-deletion-threshold-exceeded`**

The export saw more deletions than the accidental-deletion threshold (default **500**) and refused
to proceed. **This is the guard working.** The wrong response is to raise the threshold; the right
response is to find out why 500 objects vanished — nearly always an OU filter change or a moved OU.

```powershell
Get-ADSyncExportDeletionThreshold
Disable-ADSyncExportDeletionThreshold     # ONLY after confirming the deletions are intended
```

---

**Passwords silently stop syncing after an upgrade.** ⚠ Known issue: if `miiserver.exe.config`
was ever hand-edited (commonly for the FIPS `<enforceFIPSPolicy enabled="false" />` workaround),
versions **2.5.190.0** and **2.6.1.0** fail to sync after upgrade.

---

**Everything looks configured but nothing exports.** Check `StagingModeEnabled`. A staging server
imports and syncs but never exports — that is its entire purpose, and it is invisible unless you
look.

---

## 9. Customer discovery questions

1. Connect Sync or Cloud Sync, and **which version**? Is there a patching schedule, or has it run
   untouched for three years?
2. Is there a **staging server**? When was failover to it last *tested* — not planned, tested?
3. What is the **source anchor** — `ms-DS-ConsistencyGuid` or `objectGUID`? (If `objectGUID`, any
   forest migration will re-create every user.)
4. Which **writebacks** are enabled — password, device, group?
5. Are `BlockSoftMatchEnabled` and `BlockCloudObjectTakeoverThroughHardMatchEnabled` **True**?
6. Does anything rely on **`accountExpires`** for contractor offboarding? *(See §4 — likely finding.)*
7. Are the **filtering rules** OU-based or attribute-based, and who reviews them?
8. What account does the AD connector run as, and **what are its permissions**? A DCSync-capable
   account with a never-expiring password on an unpatched server is the single fattest target in
   the estate.

Question 8 is the one that turns a sync review into a security engagement.

---

## 10. Remember it

**Hook — "2 for passwords, 30 for everything else."** Password hash sync runs every 2 minutes;
object sync every 30. Users notice the asymmetry and report it as a bug.

**Analogy — a translation office.** Two embassies never speak directly. Each has an **inbox**
(connector space) where mail sits until collection time. An interpreter keeps one master notebook
(**metaverse**) with a page per person, assembled from both. That is why your change is not in
Entra yet — it is in the inbox, waiting for pickup. It is also why a **staging server** can exist:
it reads and translates but never delivers.

**The one thing:** the connector space **decouples reading from writing**. Every timing question
you will ever debug falls out of that.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

## 11. Self-test

1. A user's `department` changes in AD at 10:00. When does Entra ID show it, and why not sooner?
2. Their password changes at 10:00. When does it work in the cloud? Why is the answer different?
3. Why can't an attacker who steals the Entra ID password hash use it against on-premises AD?
4. What is the difference between *project*, *join*, and *provision*?
5. A contractor's AD account expired last night. Can they still read their mailbox?
6. Convert `a1b2c3d4-e5f6-4789-abcd-1234567890ab` to an immutableId by hand. What trips people up?
7. Export fails with `stopped-deletion-threshold-exceeded`. What do you do first?
8. Sync appears healthy, no errors, but nothing reaches Entra ID. First thing you check?

<details>
<summary>Answers</summary>

1. Next delta cycle — up to **30 minutes**. Import and export run only on schedule; the connector
   space deliberately decouples them.
2. Within about **2 minutes**. PHS runs on its own cadence, independent of the object sync cycle.
3. Entra ID stores a **salted PBKDF2/HMAC-SHA256 derivative** of the MD4 hash, not the MD4 hash.
   It is not a credential AD will accept.
4. **Project** = create a new metaverse object. **Join** = link to an existing one (evaluated
   once, never re-evaluated). **Provision** = create a downstream connector-space object, which
   changes nothing real until export.
5. **Yes.** `accountExpires` does not sync. This is the §4 finding.
6. `1MOyofbliUerzRI0VniQqw==`. The first three GUID fields are **little-endian**, so `a1b2c3d4`
   serialises as `d4 c3 b2 a1`.
7. **Do not raise the threshold.** Find out why >500 objects were deleted — almost always a
   filtering or OU change.
8. **`StagingModeEnabled`.** A staging server never exports.

</details>

---

## 12. Evidence this topic needs

- **`lab/`** — build a DC + Connect Sync server; sync one OU; capture `Get-ADSyncScheduler` output;
  change a password and time how long it takes to work in the cloud versus an attribute change.
  ✗ unrunnable without an Azure subscription or local virtualization — see
  [`../ad-ds/`](../ad-ds/).
- **`break-fix/`** — deliberately create a `proxyAddresses` duplicate, capture the export error
  verbatim, resolve it; then trip the deletion threshold by moving an OU out of scope.
- **`security/`** — the connector account's effective permissions; the four
  `OnPremiseSynchronization` feature flags with a written rationale for each; an
  `accountExpires` exposure check.
- **`operations/`** — staging-server failover runbook, with a tested (not planned) date.
- **`architecture-decisions/`** — ADR: Cloud Sync vs Connect Sync for this estate, and the
  specific feature that forces the answer.
- **`customer-use-cases/`** — the §9 discovery questions run against a real estate, with answers.

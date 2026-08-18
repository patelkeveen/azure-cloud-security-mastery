# Exchange Migrations

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Four migration types, and the arithmetic picks one.** Pairs with
> [`../coexistence/`](../coexistence/), [`../cutover-and-rollback/`](../cutover-and-rollback/) and
> [`../../35-active-directory-and-hybrid-identity/entra-connect-sync/`](../../35-active-directory-and-hybrid-identity/entra-connect-sync/).

---

## 1. What it is

Moving mailbox data from an on-premises Exchange organisation (or an IMAP source) into Exchange
Online. Microsoft ships four native paths — **cutover**, **staged**, **hybrid (remote move)** and
**IMAP** — plus the third-party route. They differ in one axis that matters more than any other:
⭐ **whether users' Outlook profiles survive the move**.

---

## 2. Why it exists

The naive approach is export-to-PST and import. That fails on four counts at once, and each one is
a real support call:

| PST export/import loses | Consequence |
|---|---|
| ⭐ **Server-side rules and delegates** | the CEO's assistant can no longer open the mailbox |
| ⭐ **The Outlook profile** | 517 desktop visits to recreate profiles |
| Item recoverability / holds | ⭐ **a compliance failure, not an inconvenience** |
| Anything created during the export | the "delta" nobody planned for |

⭐ **MRS — the Mailbox Replication Service — exists precisely to move a mailbox as a live object
with an incremental delta**, rather than as a file.

---

## 3. How it works underneath

**MRS moves mailboxes; the migration *type* only decides where MRS runs and how the client is
redirected.**

```
HYBRID (remote move)
  EXO MRS ──HTTPS──► https://mail.contoso.com/EWS/mrsproxy.svc ──► on-prem mailbox
      │                        ⭐ MRSProxy: the door MRS knocks on
      │
      ├── initial sync  (days, users online, ⭐ zero disruption)
      ├── incremental   (⭐ automatic, ~every 24 h, until you finalise)
      └── FINALISE      (minutes: lock mailbox, final delta, flip pointer)
                                     │
                                     ▼
                        on-prem mailbox becomes a ⭐ RemoteMailbox / MailUser
                        Autodiscover now returns EXO ─► ⭐ Outlook reconnects itself
```

⭐ **The pointer flip is the whole trick.** The on-premises object is not deleted — it becomes a
mail-enabled user whose `ExternalEmailAddress` is the tenant routing address, and whose
`ExchangeGUID` still matches the cloud mailbox. **Autodiscover reads that and sends Outlook to the
cloud.** No profile rebuild.

⭐ **`ExchangeGUID` is the identity of a mailbox across the move.** Every hard cross-org failure in
§7 traces back to it.

---

## 4. Worked example — a hybrid remote move, traced end to end

```powershell
# ① The endpoint: where MRS reaches on-prem. Created once.
$cred = Get-Credential                              # on-prem migration admin
New-MigrationEndpoint -ExchangeRemoteMove -Name 'OnPrem-MRS' `
    -RemoteServer 'mail.contoso.com' -Credentials $cred

# ② The batch. CSV needs one column: EmailAddress
New-MigrationBatch -Name 'Wave-01-Finance' `
    -SourceEndpoint 'OnPrem-MRS' `
    -CSVData ([System.IO.File]::ReadAllBytes('C:\mig\wave01.csv')) `
    -TargetDeliveryDomain 'contoso.mail.onmicrosoft.com' `
    -AutoStart -AutoComplete:$false        # ⭐ never AutoComplete a first wave
```

⭐ **`-AutoComplete:$false` is the single most important switch here.** It separates *copying the
data* (safe, background, reversible) from *cutting the user over* (disruptive, scheduled). With
`AutoComplete` on, a batch that finishes at 14:00 on a Tuesday cuts fifty people over mid-afternoon.

**Watching it:**

```powershell
Get-MigrationUser -BatchId 'Wave-01-Finance' | Get-MigrationUserStatistics |
  Select-Object Identity, Status, SyncedItemCount, SkippedItemCount, PercentageComplete
```

```
Identity              Status      SyncedItemCount  SkippedItemCount  PercentageComplete
j.smith@contoso.com   Synced                38211                 0                  95
a.khan@contoso.com    Syncing               12004                 3                  61
m.owusu@contoso.com   Failed                    0                 0                   0
```

⭐ **`Status: Synced` at 95 % is the normal, healthy resting state of a hybrid batch.** It is not
stuck. A remote move stops at 95 % and waits — the last 5 % *is* the finalisation. Reading that as
a failure and restarting the batch is the classic first-migration mistake.

**Finalising, on your schedule:**

```powershell
Complete-MigrationBatch -Identity 'Wave-01-Finance'
```

**The pointer, after the move — this is the evidence the mechanism worked:**

```powershell
# On-premises
Get-RemoteMailbox j.smith | Format-List ExchangeGuid, RemoteRoutingAddress
```

```
ExchangeGuid         : 8f3d1a20-4c7e-4b19-9f2a-1d5c7e0b4a63
RemoteRoutingAddress : j.smith@contoso.mail.onmicrosoft.com
```

```powershell
# Cloud — ⭐ the GUIDs must be identical
Get-Mailbox j.smith@contoso.com | Format-List ExchangeGuid
```

```
ExchangeGuid : 8f3d1a20-4c7e-4b19-9f2a-1d5c7e0b4a63
```

⭐ **Same GUID on both sides = the move was a move, not a copy.** Different GUIDs means you have two
mailboxes and a support incident.

---

## 5. Choosing the type — the decision the exam and the customer both ask

| Type | Source | Volume | ⭐ Outlook profile | Coexistence |
|---|---|---|---|---|
| **Cutover** | Exchange 2003 – 2013 | ⭐ **≤ 2,000 (practically ≤ 150)** | ⭐ **recreated** | none — all at once |
| **Staged** | Exchange 2003 / 2007 only | large | recreated | partial |
| ⭐ **Hybrid (remote move)** | Exchange 2010 SP3+ | ⭐ **unlimited** | ⭐ **survives** | ⭐ **full** |
| **IMAP** | anything with IMAP | small | recreated | ⭐ **mail only — no calendar, contacts, rules** |

⚠ `⚠ check` — the cutover ceiling is documented as **2,000** mailboxes; Microsoft's own guidance
recommends staying near **150** for a manageable weekend. Staged migration applies only to legacy
Exchange versions and is effectively dead in 2026.

⭐ **The 2026 reality that changes this table:** Exchange Server 2016 and 2019 reached end of support
on **2025-10-14**, and **Exchange Server Subscription Edition (SE)** is the only supported
on-premises version. ✅ verified as of the 2025 release cycle; ⚠ re-verify build/CU currency before
quoting. Consequence: **a customer still on 2016/2019 has an unsupported hybrid server**, which is
itself a reason to migrate — and often the reason the budget exists.

⭐ **A hybrid deployment needs at least one on-premises Exchange server to remain** for recipient
management while directory sync is in place; Microsoft provides a **free Hybrid Server licence** for
that role. Telling a customer they can remove the last Exchange server the day after migration is
the most common piece of bad advice in this field.

---

## 6. When and where

- **≤ 150 mailboxes, no compliance requirement, tolerant of a weekend outage** → cutover. Cheapest.
- ⭐ **Anything with executives, delegates, or > 3 days of wire time** → hybrid. Always.
- **Source is not Exchange** → IMAP for mail only, or a third-party tool for fidelity —
  [`../migration-tools/`](../migration-tools/).
- **Two Microsoft 365 tenants** → not this topic. [`../tenant-to-tenant/`](../tenant-to-tenant/).

---

## 7. What breaks

| Error text | Cause | Fix |
|---|---|---|
| `The connection to the server 'mail.contoso.com' could not be completed` | ⭐ **MRSProxy disabled** | `Set-WebServicesVirtualDirectory -MRSProxyEnabled $true` |
| `MigrationPermanentException: Cannot find a recipient that has mailbox GUID` | ⭐ target object missing or GUID mismatch | verify `ExchangeGuid` on both sides (§4) |
| `TooManyBadItemsPermanentException` | corrupt items exceed `BadItemLimit` | raise the limit — ⭐ **> 50 requires `-AcceptLargeDataLoss`, and that is a decision, not a flag** |
| `StalledDueToTarget_MdbAvailability` | ⭐ **EXO-side throttling** | not a fault. Wait. Do not restart the batch |
| `Outlook cannot log on` after finalise | profile cached the old server | ⭐ Autodiscover DNS still points on-prem — [`../cutover-and-rollback/`](../cutover-and-rollback/) §5 |
| Batch sits at 95 % "forever" | ⭐ **it is meant to** | `Complete-MigrationBatch` |

⭐ **`-AcceptLargeDataLoss` is the most consequential switch in Exchange migration.** It says: *I
accept that more than 50 items will be silently discarded and I will not be told which.* Use
`Get-MigrationUserStatistics -IncludeSkippedItems` to enumerate them **before** accepting —
see [`../migration-reconciliation/`](../migration-reconciliation/).

---

## 8. Customer discovery questions

1. "What Exchange version and cumulative update are you on?" (⭐ 2016/2019 is out of support)
2. ⭐ **"Can users tolerate recreating their Outlook profile?"** — this alone selects cutover vs hybrid
3. "Is there a public folder deployment?" → [`../public-folders/`](../public-folders/)
4. "Do you use Exchange for application relay? From which IPs?"
5. "Is any mailbox on litigation hold or in-place hold?"
6. ⭐ **"After migration, are you keeping any on-premises Exchange server?"**
7. "What is your maximum acceptable mail-flow outage, in minutes?"

---

## 9. Remember it

**Hook — `C S H I`: Cutover, Staged, Hybrid, IMAP** — in increasing order of fidelity and cost,
except staged, which is a fossil.

**Analogy — moving house vs forwarding post.** Cutover is packing everything into a van over one
weekend and giving everyone a new address; ⭐ **hybrid is buying the new house first, moving boxes
across for a month while living in both, then changing the address label on the door.** The analogy
predicts the mechanism: **the address label is Autodiscover, and it is the last thing you change** —
which is exactly why the profile survives.

**The one line:** ⭐ **Hybrid separates copying the data from cutting the user over; every other type
fuses them.**

---

## 10. Self-test

1. Why does a hybrid remote move not require rebuilding Outlook profiles?
   → ⭐ The on-prem object becomes a `RemoteMailbox` with the same `ExchangeGuid`; Autodiscover
   redirects the existing profile.
2. What is MRSProxy and where does it live?
   → The EWS-hosted endpoint on the on-prem CAS that EXO's MRS connects to over HTTPS.
3. A batch reports `Synced` at 95 %. What do you do?
   → ⭐ Nothing. That is the wait state. `Complete-MigrationBatch` when scheduled.
4. What does `-AcceptLargeDataLoss` actually accept?
   → Silent discard of more than 50 corrupt items per mailbox.
5. Which native type moves calendar and contacts from a non-Exchange source?
   → ⭐ None. IMAP moves mail only — that is what the third-party market sells.
6. Why must an on-prem Exchange server usually remain?
   → Recipient management while Entra Connect sync is authoritative for those objects.
7. Two mailboxes, two different `ExchangeGuid`s, one user. What happened?
   → ⭐ A new mailbox was provisioned instead of a move — data is now split.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `Get-MigrationUserStatistics` output for a real batch, pre- and post-finalise |
| `security` | proof both break-glass and service accounts were excluded from migration batches |
| `operations` | the wave plan CSV, with delegate pairs kept in the same wave |
| `break-fix` | one real MRS error and the diagnosis path that resolved it |
| `architecture-decisions` | ⭐ the cutover-vs-hybrid memo, citing §4 arithmetic and §5 table |

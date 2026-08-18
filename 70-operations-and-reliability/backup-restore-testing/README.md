# Backup and Restore Testing

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **You do not have backups. You have restores you have not tested.** Pairs with
> [`../../40-microsoft-365-platform/`](../../40-microsoft-365-platform/) and
> [`../chaos-and-failure-injection/`](../chaos-and-failure-injection/).

---

## 1. What it is

The practice of proving — repeatedly, on a schedule, with evidence — that data can be recovered
within an agreed time to an agreed point. It has two numbers (**RPO** and **RTO**), one adversary
(ransomware), and one recurring discovery: ⭐ **the backup job was green for two years and the
restore does not work.**

---

## 2. Why it exists

⭐ **A backup is a cost. A restore is the product.** Organisations buy the cost and forget the
product:

| Belief | ⭐ Reality |
|---|---|
| "The job shows success" | ⭐ **success means data was written, not that it is readable** |
| ⭐ "It's in Microsoft 365, it's safe" | ⭐ **retention ≠ backup** — see §5 |
| "We have snapshots" | ⭐ in the same subscription an attacker just compromised |
| ⭐ "We tested it at go-live" | ⭐ three years and four platform changes ago |
| "Restore takes a couple of hours" | ⭐ **nobody has measured it** |

⭐ **The last one is the most common finding, and it is quantifiable in an afternoon.** ⭐ **A
customer whose stated RTO is 4 hours and whose measured restore takes 19 is not protected — they are
mistaken**, and demonstrating that with a stopwatch is one of the highest-value things a consultant
can do in week one.

---

## 3. How it works underneath — the two numbers, drawn

```
        ⭐ RPO ─────────────►│◄──────── ⭐ RTO ─────────►
   ┌────────────────────────┬──────────────────────────┐
   │                        │                          │
last good backup      ⭐ INCIDENT              service restored
   14:00                  16:30                     20:00

  ⭐ RPO = DATA LOST      = 2h 30m of work, gone forever
  ⭐ RTO = TIME TO RECOVER = 3h 30m of outage

⭐ RPO is set by BACKUP FREQUENCY.  ⭐ RTO is set by RESTORE SPEED + PROCESS.
⭐ They are independent - improving one does nothing for the other.
```

⭐ **Conflating RPO and RTO is the most common error in this topic.** Hourly backups (excellent RPO)
sitting in cold archive that takes twelve hours to rehydrate (terrible RTO) is a real and common
configuration — ⭐ **and it satisfies neither the audit nor the business.**

⭐ **The third number nobody writes down: how long the *decision* takes.** ⭐ **In a real ransomware
event, hours pass before anyone authorises a restore** — while the scope is assessed and legal is
consulted. ⭐ **RTO measured from "decision made" is a fiction; measure it from "incident began".**

---

## 4. Worked example — the restore test that produces evidence

⭐ **A restore test is only a test if it is timed, unrehearsed, and verified by content.**

```
RESTORE TEST  RT-2026-03   Exchange Online mailbox, ⭐ UNANNOUNCED
Performed by  L. Petrov (⭐ deliberately NOT the person who built it)
Observer      D. Mwangi        Date  2026-08-14

⭐ SCENARIO GIVEN TO THE TESTER (⭐ nothing else)
  "j.smith@contoso.com reports their entire Inbox is empty as of this morning."

  T+0     Test starts. ⭐ Tester has the runbook and nothing else.
  T+4m    Located recoverable items                    ⭐ runbook step 2 wrong -
                                                          ⭐ portal path changed
  T+11m   Restore initiated
  T+38m   Restore reported complete
  T+41m   ⭐ CONTENT VERIFIED: ⭐ tester opened 3 named messages
          ⭐ from before the incident window   ← ⭐ THE ACTUAL TEST
  T+43m   ⭐ Metadata check: received dates preserved, ⭐ folder structure intact

⭐ RESULT   RTO measured 43 min  (⭐ target: 4 h)  PASS
⭐ FINDING  ⭐ Runbook step 2 references a UI path that no longer exists.
           ⭐ Fixed same day. THIS is the value of the test.
⭐ FINDING  ⭐ Tester needed a role they did not have; ⭐ 4 min lost obtaining it.
           → ⭐ add the required role to the runbook header.
```

⭐ **"Content verified: opened three named messages" is the step that makes it a test.** ⭐ **A
restore job reporting `Completed` proves the software ran** — it does not prove the data is readable,
correct, or from the right point in time. ⭐ **Open the file. Read the row. Check the date.**

⭐ **Deliberately choosing a tester who did not build the system is the second design decision**,
and it is the same separation-of-duties logic as verifier ≠ executor in a cutover. ⭐ **The builder
knows the undocumented step; the person restoring at 03:00 next year will not.**

⭐ **Both findings came from the process, not the technology.** That is typical: ⭐ **restore tests
overwhelmingly fail on stale documentation and missing permissions rather than on corrupt data.**

---

## 5. ⭐ Microsoft 365 — retention is not backup

⭐ **This is the most consequential misunderstanding in the M365 world, and it is worth being able
to state precisely.**

| Native feature | What it actually gives you | ⭐ Where it fails |
|---|---|---|
| Deleted items retention | ⭐ default **14 days**, configurable to **30** | ⭐ past that, gone |
| Recoverable items | a window, not a point-in-time copy | ⭐ **cannot restore to "last Tuesday"** |
| ⭐ SharePoint recycle bins | ⭐ **93 days** total across both stages | fixed ceiling |
| Retention policies | ⭐ **prevent deletion** | ⭐ **not a restore mechanism** |
| Litigation hold | preserves for legal discovery | ⭐ same — preservation, not recovery |
| Versioning | previous versions of a file | ⭐ **ransomware encrypts, creating new versions** |
| Entra deleted users | **30 days** | then permanent |

⚠ `⚠ check` — these defaults and ceilings change; verify each against current Microsoft
documentation before quoting them in a design.

⭐ **The distinction that matters: retention prevents deletion; backup enables restoration to a
point in time.** ⭐ **They solve different problems, and no amount of retention gives you "restore
the finance site as it was on 3 March".**

⭐ **The Microsoft shared responsibility position is explicit: Microsoft protects the *service*; the
*data* remains the customer's responsibility.** ⭐ **Saying that sentence in a customer conversation
— and then asking what their recovery point is for a mailbox deleted 60 days ago — is how the
third-party backup conversation should start**, rather than with a product pitch.

---

## 6. Commands — evidence, not dashboards

```powershell
# ⭐ Are backups actually recent?  A green job list is not the same question.
Get-AzRecoveryServicesBackupJob -Status Completed -From (Get-Date).AddDays(-7) |
  Group-Object WorkloadName | ForEach-Object {
    [pscustomobject]@{
      Item      = $_.Name
      LastGood  = ($_.Group | Sort-Object EndTime -Desc | Select-Object -First 1).EndTime
      Runs7d    = $_.Count
    }
  } | Sort-Object LastGood
```

```
Item              LastGood             Runs7d
sql-contoso-prod  09/08/2026 02:14:11       1   ⭐ 5 DAYS OLD - daily schedule
vm-app-prod       14/08/2026 02:07:44       7
```

⭐ **`Runs7d = 1` on a daily schedule means six failures, and the dashboard was showing green
because it displays the successful run.** ⭐ **Sort by `LastGood` ascending and read the top row —
that single habit finds more real gaps than any report.**

**Ransomware hardening — ⭐ the controls that decide whether backups survive the attack:**

```powershell
Get-AzRecoveryServicesVault | ForEach-Object {
  Set-AzRecoveryServicesVaultContext -Vault $_
  [pscustomobject]@{
    Vault           = $_.Name
    SoftDelete      = (Get-AzRecoveryServicesVaultProperty -VaultId $_.ID).SoftDeleteFeatureState
    Immutability    = (Get-AzRecoveryServicesVault -Name $_.Name -ResourceGroupName $_.ResourceGroupName).Properties.ImmutabilitySettings.State
  }
}
```

```
Vault            SoftDelete  Immutability
rsv-contoso-prod  Enabled     Unlocked
```

⭐ **`Immutability: Unlocked` means an attacker with vault permissions can still turn it off.**
⭐ **Locked immutability is irreversible — deliberately — and that irreversibility is the entire
security property.** Combined with **multi-user authorisation**, it means ⭐ **no single compromised
admin account can destroy the backups**, which is precisely what modern ransomware attempts first.

⚠ `⚠ check` — vault property cmdlets and immutability states vary by Az module version.

---

## 7. When and where

| Data | Backup approach |
|---|---|
| Azure VMs, SQL, Files | Azure Backup + ⭐ locked immutable vault + MUA |
| ⭐ Microsoft 365 | ⭐ retention for compliance + ⭐ **third-party backup for point-in-time** |
| ⭐ Entra configuration | ⭐ **export policies as JSON to Git** — [`../../75-architecture-and-consulting/lld/`](../../75-architecture-and-consulting/lld/) §6 |
| IaC-defined infrastructure | ⭐ the repository **is** the backup |
| ⭐ Anything, anywhere | ⭐ **a copy outside the blast radius** |

⭐ **"Outside the blast radius" is the principle that survives every technology change.** ⭐ **A
backup in the same subscription, reachable by the same admin credentials, is not a backup against
the threat that matters** — it is protection against hardware failure only, which is not the modern
risk.

⭐ **Backing up Entra and Conditional Access configuration as JSON in Git costs nothing and is almost
never done.** A deleted or corrupted CA policy set is a genuine outage with no native restore.

---

## 8. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Restore fails when needed | ⭐ never tested | ⭐ scheduled, unannounced tests |
| ⭐ Dashboard green, backups 5 days old | ⭐ reading successes, not the **latest** | ⭐ sort by `LastGood` |
| ⭐ Restore works, data is wrong | ⭐ no **content** verification | open named files; check dates |
| Backups encrypted by ransomware | ⭐ same credential domain | immutability + MUA + offsite |
| ⭐ "It's in M365 so it's backed up" | ⭐ retention ≠ backup | §5 |
| RTO missed despite fast restore | ⭐ **decision time not counted** | measure from incident start |
| Runbook step wrong | UI changed | ⭐ the test finds this — that is its job |

⭐ **Test failures are the deliverable, not an embarrassment.** ⭐ **A restore test that finds nothing
either means the system is genuinely excellent or the test was too easy** — and the second is far
more likely, so vary the scenario each time.

---

## 9. Customer discovery questions

1. ⭐ **"When did you last perform a restore, and how long did it take?"**
2. "What is your RPO and RTO, and who agreed them?"
3. ⭐ **"Can you restore a mailbox to how it looked on a specific date 60 days ago?"**
4. "Could an attacker with your admin credentials delete the backups?"
5. ⭐ **"Is immutability locked, or can it be switched off?"**
6. "Who authorises a restore, and how long does that take?"
7. ⭐ **"Is your Conditional Access configuration backed up anywhere?"**

---

## 10. Remember it

**Hook — `R R V`: RPO (data lost), RTO (time down), ⭐ **V**erify the content.** ⭐ Two numbers and
the step everyone skips.

**Analogy — a fire drill, not a fire extinguisher on the wall.** ⭐ **The extinguisher being present
and in-date (the green backup job) tells you nothing about whether anyone can find the exit in
smoke.** The analogy predicts every rule here: ⭐ **you run the drill unannounced, you time it, you
use someone who does not know the building, and the point of the drill is to find the fire door that
has been propped shut** — which is exactly the runbook step referencing a UI that no longer exists.

**The one line:** ⭐ **A backup job reporting success proves data was written; only a timed restore
with content verification proves it can come back.**

---

## 11. Self-test

1. Difference between RPO and RTO, and what sets each?
   → ⭐ RPO = data lost, set by backup frequency. RTO = time down, set by restore speed and process.
2. Why is a `Completed` restore job insufficient evidence?
   → ⭐ It proves the software ran, not that the data is readable, correct, or from the right point.
3. Why is M365 retention not a backup?
   → ⭐ Retention prevents deletion; it cannot restore to an arbitrary point in time.
4. What does locked immutability protect against, specifically?
   → ⭐ An attacker with vault permissions turning protection off before destroying backups.
5. Which hidden interval breaks stated RTOs?
   → ⭐ Decision time — measure RTO from incident start, not from authorisation.
6. Why should the restore tester not be the person who built it?
   → ⭐ The builder knows the undocumented steps; the 03:00 responder will not.
7. What is the most common cause of restore-test failure?
   → ⭐ Stale documentation and missing permissions — not corrupt data.

---

## 12. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ one timed restore test with the scenario, elapsed time and content verification |
| `security` | vault soft-delete, immutability state and MUA configuration |
| `operations` | ⭐ the `LastGood` query output, showing any stale items |
| `break-fix` | ⭐ the runbook defect the test exposed, and the same-day fix |
| `architecture-decisions` | ⭐ the retention-vs-backup decision for M365, written for the customer |

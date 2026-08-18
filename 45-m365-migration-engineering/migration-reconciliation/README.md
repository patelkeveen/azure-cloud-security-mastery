# Migration Reconciliation

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **"Completed" is a tool's opinion. Reconciliation is evidence.** Pairs with
> [`../cutover-and-rollback/`](../cutover-and-rollback/) and
> [`../../70-operations-and-reliability/root-cause-analysis/`](../../70-operations-and-reliability/root-cause-analysis/).

---

## 1. What it is

The measured comparison of source and target after a migration: item counts, sizes, folder
structure, permissions and mail-flow endpoints — producing a signed statement of what moved, what
did not, and what was **deliberately** discarded.

⭐ **It is the deliverable that ends the engagement.** Without it, the project has no defensible end
and every future missing email is your fault by default.

---

## 2. Why it exists

Every migration engine has a **tolerated loss** setting, and its default is not zero:

| Mechanism | Default behaviour | ⭐ What the dashboard shows |
|---|---|---|
| `BadItemLimit` on a move | corrupt items skipped up to the limit | ⭐ **`Completed`** |
| ⭐ `-AcceptLargeDataLoss` | > 50 items discarded, silently | ⭐ **`Completed`** |
| SPMT failed files | logged to CSV, run continues | ⭐ **100 %** |
| Label collapse (Google) | messages merged into one folder | ⭐ **success** |

⭐ **Every one of those reports success.** ⭐ **"Completed" means the process finished, not that the
data arrived** — and the gap between those two sentences is the entire reason this topic exists.

⭐ **The customer will discover the loss six months later, when they need the one message that was
skipped.** At that point the only thing that protects you is a document you produced at the time.

---

## 3. How it works underneath — reconcile on four axes, not one

```
① COUNT        source items  vs  target items        ⭐ per folder, not per mailbox
② SIZE         source bytes  vs  target bytes        ⭐ expect target ≠ source (see §4)
③ STRUCTURE    folder tree present and named         ⭐ the empty-folder check
④ FUNCTION     ⭐ can the user DO the thing?          delegates, rules, mail-enabled
                   addresses, shared calendars
                        │
                        ▼
        RECONCILIATION REPORT  →  ⭐ signed by the customer
```

⭐ **Axis ④ is the one that matters to the customer and the one nobody automates.** Counts can match
perfectly while the finance team cannot open the shared mailbox they use every morning.

---

## 4. Worked example — why sizes never match, and how to know it is fine

Same mailbox, both sides:

```
SOURCE  (Exchange 2019)         TARGET (Exchange Online)
  ItemCount   : 38,211            ItemCount   : 38,211      ✅ equal
  TotalSize   : 4.71 GB           TotalSize   : 4.38 GB     ⭐ 7 % SMALLER
```

⭐ **A smaller target is normal and expected.** Three reasons, all benign:

| Reason | Effect |
|---|---|
| ⭐ **Single-instance / storage differences** | EXO stores and compresses differently |
| Deleted-item retention not carried | recoverable items may not be counted the same way |
| Attachment de-duplication and re-encoding | small per-item deltas that accumulate |

⭐ **So size is a weak signal and item count is a strong one.** The rule that separates a real
problem from noise:

```
⭐ ItemCount mismatch  →  INVESTIGATE. Always.
   Size mismatch ≤ 10 % with matching counts  →  expected
   Size mismatch > 20 % with matching counts  →  ⚠ investigate anyway
```

**Enumerate what was actually skipped — before signing anything:**

```powershell
Get-MigrationUser -Identity a.khan@contoso.com |
  Get-MigrationUserStatistics -IncludeSkippedItems |
  Select-Object -ExpandProperty SkippedItems |
  Select-Object Subject, Kind, FolderName, ScoringClassifications
```

```
Subject                    Kind         FolderName   ScoringClassifications
Scanned invoice 4471.tif   CorruptItem  Inbox        CorruptItem
(no subject)               MissingItem  Sent Items   MissingItem
```

⭐ **Two items, named.** That is a reconciliation finding you can hand to the customer: *"two items
did not move; here they are; here is where they were."* ⭐ **"Fewer than fifty items were skipped" is
not a finding — it is an excuse with a number in it.**

**The per-folder comparison — where empty folders surface:**

```powershell
Get-MailboxFolderStatistics a.khan@contoso.com |
  Where-Object FolderType -eq 'User' |
  Select-Object FolderPath, ItemsInFolder |
  Export-Csv .\target-folders.csv -NoTypeInformation
```

```
FolderPath              ItemsInFolder
/Inbox                          8,204
/Inbox/Finance                  4,182
/Inbox/Q3-2024                      0    ⭐ FINDING
/Sent Items                    11,003
```

⭐ **A folder with zero items in the target and content in the source is the single highest-value
row in any reconciliation report** — and it is invisible at mailbox level, because the totals match.

---

## 5. Commands — the reconciliation set

```powershell
# ① Batch-level truth
Get-MigrationBatch | Select-Object Identity, Status, TotalCount, FailedCount
```

```
Identity         Status     TotalCount  FailedCount
Wave-01-Finance  Completed          52            0
```

```powershell
# ② Per-user, including data loss actually accepted
Get-MigrationUser -BatchId 'Wave-01-Finance' | Get-MigrationUserStatistics |
  Select-Object Identity, Status, SyncedItemCount, SkippedItemCount
```

```
Identity              Status     SyncedItemCount  SkippedItemCount
a.khan@contoso.com    Completed            38211                 2
j.smith@contoso.com   Completed            12994                 0
```

```powershell
# ③ ⭐ FUNCTION — the axis that generates tickets
Get-MailboxPermission finance@contoso.com |
  Where-Object { -not $_.IsInherited -and $_.User -notlike 'NT AUTHORITY\*' } |
  Select-Object User, AccessRights
Get-InboxRule -Mailbox a.khan@contoso.com | Select-Object Name, Enabled, Description
```

⭐ **Run ③ against the *source* export taken at discovery.** Reconciliation without a
pre-migration baseline is not reconciliation — it is a description of the current state. ⭐ **The
baseline is what makes the comparison possible, and it must be captured before wave one.**

---

## 6. When and where

| Timing | What to reconcile |
|---|---|
| ⭐ Per wave, within 48 h | counts + skipped items, while a re-pull is still possible |
| At cutover | ⭐ mail-flow endpoints and mail-enabled public folders |
| ⭐ Project close | ⭐ **the signed report** — counts, exceptions, accepted losses |
| ⭐ Before source decommission | ⭐ **final gate. Nothing is recoverable afterwards** |

⭐ **Reconcile per wave, not at the end.** A discrepancy found in week two can be fixed by re-running
one mailbox. The same discrepancy found in week ten, after the source is gone, cannot be fixed at
all — and the cost difference between those two moments is the whole argument for the cadence.

---

## 7. What breaks

| Symptom | Cause | Response |
|---|---|---|
| Counts match, users report missing mail | ⭐ **per-folder** mismatch hidden by totals | folder-level comparison (§4) |
| Target 30 % smaller | genuinely missing data, ⭐ not just storage difference | investigate before signing |
| `SkippedItemCount` non-zero, nobody informed | ⭐ report never read | ⭐ **name the items in the report** |
| Report cannot be produced at all | no pre-migration baseline | ⭐ unrecoverable — capture at discovery next time |
| Customer disputes completeness months later | no signed statement | ⭐ this is what §1 prevents |
| Rules and delegates gone | not in scope of the data move | reapply from the baseline export |

⭐ **The unrecoverable failure in this topic is procedural, not technical: no baseline.** You cannot
reconcile against a source you no longer have, and by then the tool has reported success and the
invoice has been paid.

---

## 8. Customer discovery questions

1. ⭐ **"What evidence do you need in order to sign off, and who signs?"**
2. "Is there a regulatory retention obligation that a skipped item would breach?"
3. ⭐ **"How long will the source remain available after cutover?"**
4. "Is an item count acceptable as proof, or do you need per-folder detail?"
5. "Who reviews the skipped-item list, and how quickly?"
6. ⭐ **"What is your tolerance for corrupt-item loss — zero, or a documented number?"**
7. "Do rules, delegates and categories need to be verified individually?"

---

## 9. Remember it

**Hook — `C S S F`: Count, Size, Structure, Function.** Count is the strong signal; ⭐ **Function is
the one the customer feels.**

**Analogy — a stocktake after moving a warehouse.** ⭐ **The lorry driver saying "all delivered" is
the migration tool. The stocktake is counting the shelves.** The analogy predicts the practice:
**you count against the manifest written before loading (the baseline), you count per shelf rather
than per lorry (per folder), and you check the till actually opens (function).** It also predicts
the failure: **no manifest, no stocktake.**

**The one line:** ⭐ **A tool reports that it finished; reconciliation proves what arrived — and it
needs a baseline captured before wave one.**

---

## 10. Self-test

1. Why is "Completed" insufficient evidence?
   → ⭐ It reports process completion; skipped and corrupt items are tolerated by design.
2. Target is 7 % smaller with identical item counts. Problem?
   → ⭐ No — storage and encoding differences. Count is the strong signal.
3. Which command names the items that were skipped?
   → `Get-MigrationUserStatistics -IncludeSkippedItems`.
4. Why reconcile per folder rather than per mailbox?
   → ⭐ A whole missing folder can hide inside a matching mailbox total.
5. What is the fourth axis, and why is it hardest to automate?
   → ⭐ Function — delegates, rules, mail-enabled addresses. It is about capability, not data.
6. What makes a discrepancy unrecoverable?
   → ⭐ Source decommissioned, or no pre-migration baseline.
7. Why reconcile per wave rather than at project end?
   → ⭐ A wave-two discrepancy can be re-pulled; a week-ten one cannot.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | source and target folder-statistics CSVs, with the diff |
| `security` | permission comparison before and after, including any that were not restored |
| `operations` | the per-wave reconciliation cadence, with dates |
| `break-fix` | one named skipped item, its classification, and the decision taken |
| `architecture-decisions` | ⭐ the signed completion report and the accepted-loss statement |

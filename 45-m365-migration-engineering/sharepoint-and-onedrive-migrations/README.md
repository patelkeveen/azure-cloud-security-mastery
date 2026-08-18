# SharePoint and OneDrive Migrations

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **A file system has no rules. SharePoint has many.** The migration is mostly the remediation.
> Pairs with [`../discovery-and-assessment/`](../discovery-and-assessment/) and
> [`../migration-tools/`](../migration-tools/).

---

## 1. What it is

Moving file content — from Windows file shares, SharePoint Server, Google Drive, Box or Dropbox —
into SharePoint Online document libraries and OneDrive for Business. Microsoft ships two free
tools: the **SharePoint Migration Tool (SPMT)** for direct source-to-target runs, and
**Migration Manager** in the SharePoint admin centre, which orchestrates **agents** across many
file servers at once.

---

## 2. Why it exists

⭐ **A file share accepts filenames SharePoint rejects, and paths SharePoint cannot address.** Drag
and drop discovers this one file at a time, in front of the customer. The tools exist to discover
it in bulk, beforehand, and to preserve what drag-and-drop destroys:

| Drag and drop loses | Migration tool preserves |
|---|---|
| ⭐ **Created / Modified dates** | ⭐ **original timestamps and authors** |
| Version history | versions, up to a configured depth |
| ⭐ **NTFS permissions** | mapped to SharePoint groups (⭐ if identities are mapped) |
| Nothing resumable | incremental re-runs |

⭐ **"The files all say modified today by the admin" is the signature of a drag-and-drop
migration**, and it destroys every retention calculation the customer has.

---

## 3. How it works underneath

SPMT does not upload files one by one over the UI path. It **packages**:

```
SOURCE (file share / SP Server)
   │
   ① SCAN      ⭐ enumerate, validate names, measure paths, list blockers
   │
   ② PACKAGE   build a migration manifest + content package
   │
   ③ UPLOAD    ──► Azure blob staging (⭐ Microsoft-provided or your own)
   │
   ④ IMPORT    ⭐ SharePoint Migration API pulls from blob asynchronously
   │              (this is why throughput is not your bandwidth alone)
   ▼
TARGET library  +  per-run CSV report
```

⭐ **Step ④ is server-side and queued.** Your upload finishing does not mean the migration finished
— and this is the single most common misreading of a migration dashboard.

---

## 4. Worked example — the limits, applied to one real path

A file on the source share:

```
\\FS01\Shared\Departments\Finance\2019\Quarterly Reporting\
   Draft v2 [FINAL] - Q3 Reconciliation & Variance <internal>.xlsx
```

Target site: `https://contoso.sharepoint.com/sites/FinanceOperationsAndReporting`

**Two independent failures in one file:**

| Check | Value | Limit | Verdict |
|---|---|---|---|
| Invalid characters | ⭐ `<` and `>` | not permitted in a name | ⭐ **FAIL** |
| Full decoded path | 231 chars | **400** | pass |

⭐ **The characters SharePoint Online rejects in a file or folder name:** `" * : < > ? / \ |`.
Also rejected: names beginning or ending with a **space**, names ending with a **period**, the
leading sequence `~$`, and the reserved name `.lock`. ✅ verified against Microsoft's
"Invalid file names and file types in OneDrive and SharePoint" guidance; ⚠ re-verify at engagement
time — this list has changed twice.

**The path arithmetic that actually bites:**

```
https://contoso.sharepoint.com/sites/FinanceOperationsAndReporting   = 62
/Shared Documents                                                    = 16
/Departments/Finance/2019/Quarterly Reporting                        = 44
/Draft v2 [FINAL] - Q3 Reconciliation and Variance internal.xlsx     = 63
                                                              TOTAL  = 185  ✅
```

⭐ **Now move the same tree three folders deeper under a site named
`/sites/GlobalFinanceOperationsAndStatutoryReporting2019Archive` and the same file fails at 400.**
The file did not change — **the destination design did**. This is why the site architecture must be
agreed *before* the scan, not after.

⭐ **Other limits worth knowing by number:**

| Limit | Value |
|---|---|
| Full decoded URL path | **400** characters |
| ⭐ Single file upload | **250 GB** |
| Site collection storage | **25 TB** |
| Items in a list/library | 30 million (⭐ but the **5,000** *list view threshold* bites first) |

⚠ `⚠ check` — service limits change; confirm each against current Microsoft documentation before
putting a number in a customer document.

---

## 5. Commands

**SPMT via PowerShell — the repeatable way, because the GUI is not evidence:**

```powershell
Install-Module Microsoft.SharePoint.MigrationTool.PowerShell
Register-SPMTMigration -SPOCredential $cred -Force

Add-SPMTTask -FileShareSource '\\FS01\Shared\Finance' `
             -TargetSiteUrl 'https://contoso.sharepoint.com/sites/Finance' `
             -TargetList 'Documents' `
             -TargetListRelativePath 'Departments/Finance'

Start-SPMTMigration
```

**Progress:**

```powershell
Get-SPMTMigration | Select-Object Status, NumScannedFiles, NumFailedFiles, MigratingProgressPercentage
```

```
Status     NumScannedFiles  NumFailedFiles  MigratingProgressPercentage
INPROGRESS           48211              37                           72
```

⭐ **`NumFailedFiles` is the only number that matters at the end.** A run that reports 100 % with
37 failures migrated 37 files fewer than the customer thinks, and the per-file reason is in the
run's CSV report under `%APPDATA%\Microsoft\MigrationTool\`.

**Pre-flight the destination, always:**

```powershell
Get-SPOSite -Identity https://contoso.sharepoint.com/sites/Finance |
  Select-Object StorageQuota, StorageUsageCurrent, LockState
```

```
StorageQuota  StorageUsageCurrent  LockState
     1048576                  412  Unlock
```

⭐ **`LockState: ReadOnly` is a silent migration killer** — the run reports permission errors that
look like credential problems.

---

## 6. When and where

| Source | Tool |
|---|---|
| File share, < ~1 TB, single site | ⭐ **SPMT** — free, simplest |
| Many file servers, many shares | ⭐ **Migration Manager** with agents — parallel, centrally tracked |
| SharePoint Server 2013+ | SPMT or Migration Manager |
| ⭐ **Google Drive / Box / Dropbox** | Migration Manager connectors — [`../google-workspace-to-m365/`](../google-workspace-to-m365/) |
| Complex permission remapping, cross-tenant | ⭐ third party (ShareGate, AvePoint) — [`../migration-tools/`](../migration-tools/) |

⭐ **Choose by the *permission* problem, not the data volume.** Copying bytes is solved; deciding
who can read them in the target is what you are actually paid for.

---

## 7. What breaks

| Error text | Cause | Fix |
|---|---|---|
| `The file name or folder name contains invalid characters` | §4 character set | ⭐ bulk-rename at source **before** the run |
| `The specified path is too long` | > 400 decoded chars | ⭐ flatten the destination folder structure |
| `HTTP 429 Too Many Requests` / `503` | ⭐ **SharePoint throttling** | honour `Retry-After`; reduce concurrent agents; run overnight |
| `File is checked out` | checked-out with unpublished changes | ⭐ discard or force check-in — SMAT lists them |
| Files migrate, permissions do not | identity mapping absent | map source SIDs / Google accounts to Entra users first |
| All files show today's date | ⭐ **drag and drop was used** | re-run with a tool; metadata cannot be recovered afterwards |

⭐ **Throttling is not a bug and cannot be raised by asking.** SharePoint Online returns `429` with
a `Retry-After` header; a well-behaved tool sleeps for exactly that long. ⭐ **A tool that retries
immediately makes throttling worse and can extend a run by days** — this is the practical
difference between migration tools, far more than feature lists.

---

## 8. Customer discovery questions

1. ⭐ **"How deep is your deepest folder, and how long is the longest filename?"**
2. "Do you need version history, and how many versions?" (⭐ each version is billed storage)
3. "Who owns permissions today — NTFS groups, or per-user ACLs?"
4. ⭐ **"Are there files nobody has opened in five years?"** — the cheapest migration is the one you
   do not do
5. "Is anything checked out, or in a workflow?"
6. "What is your target information architecture — one site or many?"
7. "Are OneDrive accounts already provisioned for every user?"

---

## 9. Remember it

**Hook — `S P U I`: Scan, Package, Upload, Import.** Two of the four are Microsoft's, not yours.

**Analogy — airport baggage.** You check the bag (upload); ⭐ **it then travels on a conveyor you do
not control and cannot speed up (the server-side import queue)**. The analogy predicts the two real
failures: **oversized/prohibited items are rejected at check-in (invalid characters, path length),
and at peak times the conveyor throttles everyone equally (429).** Shouting at the desk changes
nothing — which is exactly the correct response to throttling.

**The one line:** ⭐ **The migration is easy; the remediation of names, paths and permissions is the
project.**

---

## 10. Self-test

1. Full decoded URL path limit?
   → **400** characters.
2. Name five characters invalid in a SharePoint filename.
   → Any five of `" * : < > ? / \ |`.
3. Upload finished at 100 %. Is the migration complete?
   → ⭐ No — server-side import is queued and asynchronous.
4. What does HTTP 429 mean here, and the correct response?
   → Throttling; sleep for `Retry-After` and reduce concurrency.
5. Why does the destination site name affect whether a source file can migrate?
   → ⭐ It consumes part of the 400-character budget.
6. Which single symptom proves drag-and-drop was used?
   → All items modified today by the migrating account.
7. Why is 5,000 more operationally relevant than 30 million?
   → ⭐ The list view threshold breaks *views*, and users meet it long before the item ceiling.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | an SPMT run report CSV, including at least one failed file with its reason |
| `security` | before/after permission comparison for one library |
| `operations` | the throttling observation: timestamps of `429`s and the concurrency change made |
| `break-fix` | one path-length or invalid-character remediation, with the rename script |
| `architecture-decisions` | ⭐ the information-architecture decision, showing the path-length budget |

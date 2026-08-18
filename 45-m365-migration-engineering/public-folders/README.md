# Public Folders

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The workload every customer says they do not use, and every customer uses.** Pairs with
> [`../discovery-and-assessment/`](../discovery-and-assessment/) and
> [`../exchange-migrations/`](../exchange-migrations/).

---

## 1. What it is

Public folders are a shared hierarchy of mail-and-item folders that predate SharePoint, Teams and
shared mailboxes. In Exchange Online they are stored in **public folder mailboxes**: one holds the
**primary hierarchy** (writable), the rest hold **content** and a read-only hierarchy copy.

⭐ **There is exactly one writable copy of the hierarchy in the entire organisation.** Almost every
public folder oddity descends from that single fact.

---

## 2. Why it exists as a migration problem

⭐ **Public folders are usually load-bearing and undocumented.** The typical finding:

| Discovered | Business meaning |
|---|---|
| `\Sales\Quotes 2011-2024` | ⭐ the only archive of what was quoted to whom |
| ⭐ **6 mail-enabled folders** | ⭐ **live SMTP addresses customers still send to** |
| `\HR\Calendar` | the leave calendar the whole department opens in Outlook |
| Root permissions: `Default = Owner` | ⭐ every user can delete the hierarchy |

⭐ **A mail-enabled public folder is an active mail-flow dependency.** Miss one and a customer-facing
address stops accepting mail on cutover night — with no bounce visible to your team, because the
NDR goes to the *sender*.

---

## 3. How it works underneath

```
PUBLIC FOLDER MAILBOX #1  ⭐ PRIMARY HIERARCHY   ← the only WRITABLE copy
      │  (folder names, structure, permissions, mail-enabling)
      │
      ├─ replicated read-only ──► PF mailbox #2 (content)
      ├─ replicated read-only ──► PF mailbox #3 (content)
      │
CONTENT lives in whichever PF mailbox the folder is ⭐ HOMED to
      │
CLIENT: Outlook reads the hierarchy from its default PF mailbox,
        then is ⭐ REDIRECTED to the mailbox holding the content
```

⭐ **Two hops per access: hierarchy, then content.** That is why public folders feel slow, why a
hierarchy sync lag makes a new folder "invisible" to some users for a while, and why capacity
planning is per-mailbox rather than per-folder.

⭐ **Split by size, not by department.** A folder tree cannot span public folder mailboxes; a single
folder's content lives entirely in one. If one department's tree exceeds the mailbox ceiling, the
migration plan must split *inside* that tree.

---

## 4. Worked example — sizing the target from real statistics

Microsoft ships the scripts; the judgement is yours.

```powershell
# ① On-premises: export the real shape of the hierarchy
.\Export-ModernPublicFolderStatistics.ps1 C:\mig\pf-stats.csv
```

```
FolderName,FolderSize,ItemCount
\,0,0
\Sales,0,0
\Sales\Quotes,4831838208,118422
\HR\Calendar,204818432,3110
```

⭐ **`\Sales\Quotes` is 4.83 GB with 118,422 items** — one folder, and it is 4 % of the way to a
public folder mailbox ceiling on its own.

```powershell
# ② Generate the folder-to-mailbox map. The size argument is the DESIGN decision.
.\ModernPublicFolderToMailboxMapGenerator.ps1 `
    -MailboxSize 50GB -MailboxRecoverableItemSize 15GB `
    -ImportFile C:\mig\pf-stats.csv -ExportFile C:\mig\pf-map.csv
```

```
TargetMailbox,FolderPath
Mailbox1,\
Mailbox1,\Sales
Mailbox1,\Sales\Quotes
Mailbox2,\HR
Mailbox2,\HR\Calendar
```

⭐ **Passing `-MailboxSize 50GB` rather than the 100 GB ceiling is deliberate**: it leaves headroom
for growth after migration. ⭐ **Sizing to the ceiling means the first year of normal use breaks
it**, and rebalancing public folder mailboxes afterwards is far more disruptive than creating one
extra now.

**Known limits — the numbers that constrain the design:**

| Limit | Value |
|---|---|
| Public folder mailboxes per tenant | **1,000** |
| ⭐ Size per public folder mailbox | **100 GB** |
| Recommended items in a single folder | ~1,000,000 |
| Subfolders under one parent | ~10,000 |

⚠ `⚠ check` — these are the widely documented Exchange Online public folder limits, but they have
been revised more than once. **Verify each against current Microsoft service limits before writing
them into a design document.**

---

## 5. Commands

**Find the mail-enabled folders — do this in the first hour of discovery:**

```powershell
Get-PublicFolder -Recurse -ResultSize Unlimited |
  Where-Object MailEnabled -eq $true |
  ForEach-Object {
      $m = Get-MailPublicFolder $_.Identity
      [pscustomobject]@{ Folder=$_.Identity; SMTP=$m.PrimarySmtpAddress }
  }
```

```
Folder                    SMTP
\Sales\Enquiries          enquiries@contoso.com
\Support\Tickets          support@contoso.com
```

⭐ **Those SMTP addresses are printed on the customer's website and on invoices.** They must exist
and route correctly the moment MX changes — see [`../cutover-and-rollback/`](../cutover-and-rollback/) step 7.

**Post-migration verification — hierarchy and content are separate checks:**

```powershell
Get-Mailbox -PublicFolder | Select-Object Name, IsRootPublicFolderMailbox
Get-PublicFolder -Recurse -ResultSize Unlimited | Measure-Object | Select-Object Count
```

```
Name        IsRootPublicFolderMailbox
PFMailbox1  True
PFMailbox2  False

Count
-----
  1874
```

⭐ **Compare `1874` to the source count.** Public folder migration is the workload where a missing
subtree is easiest to overlook, because nobody opens most of the hierarchy on any given day.

---

## 6. When and where — the decision nobody makes early enough

| Target | When it is right |
|---|---|
| ⭐ **Public folders in EXO** | ⭐ genuinely shared *mail* archives, mail-enabled addresses, or Outlook-only users |
| **Shared mailbox** | ⭐ **a mail-enabled folder that is really a team inbox** — usually the right answer |
| **Microsoft 365 group / Teams** | ⭐ active collaboration, not archive |
| **SharePoint** | documents that ended up in a public folder because it was the only shared place in 2009 |
| ⭐ **Delete** | ⭐ untouched for five years. Ask; it is often most of the tree |

⭐ **The consulting value here is subtraction.** A 60 GB public folder tree where 45 GB has not been
opened since 2018 should be archived and deleted, not migrated — and saying so, with the access
dates to prove it, is worth more than a flawless migration of dead data.

---

## 7. What breaks

| Error text / symptom | Cause | Fix |
|---|---|---|
| `The public folder mailbox ... has exceeded its size limit` | sized to the ceiling | ⭐ split the map; re-run with a smaller `-MailboxSize` |
| Users cannot see a new folder | ⭐ hierarchy sync lag | wait; it is a replicated read-only copy |
| Mail to `enquiries@contoso.com` bounces after cutover | ⭐ **mail-enabled folder not migrated or not re-enabled** | verify `Get-MailPublicFolder` in the target |
| `Cannot open the public folder store` in Outlook | default PF mailbox not set for the user | `Set-Mailbox -DefaultPublicFolderMailbox` |
| Permissions gone after migration | ⭐ ACLs referenced deleted or unmigrated accounts | remediate identities **before** the PF batch |
| Migration completes, folders empty | content mailbox mapping wrong | check `pf-map.csv` against actual homing |

⭐ **Legacy public folders and modern public folders cannot coexist across a migration**: during the
final lock, the source hierarchy is made read-only, and there is no partial state. Public folders
are therefore a **single cutover**, not a waved one — even when mailboxes are waved. Design the
schedule around that.

---

## 8. Customer discovery questions

1. ⭐ **"Which public folders receive mail from outside?"** (run the §5 command regardless of the answer)
2. "When was each top-level folder last modified?"
3. ⭐ **"Who would notice if `\Sales\Quotes` disappeared?"**
4. "Is any public folder used by an application or a workflow?"
5. "Are there calendars or contact folders in the hierarchy?" (⭐ these are the ones users open daily)
6. "What is the total size, and how much of it is older than five years?"
7. ⭐ **"Would a shared mailbox or a Team serve this better?"**

---

## 9. Remember it

**Hook — `H C M`: Hierarchy (one writable), Content (homed per mailbox), Mail-enabled (live SMTP).**

**Analogy — a library.** ⭐ **There is exactly one master catalogue (the primary hierarchy) and many
shelves (content mailboxes).** You look a book up in the catalogue, then walk to whichever shelf
holds it. The analogy predicts the behaviour: **a book added today may not be in every printed
catalogue copy yet (hierarchy lag), a shelf can only hold so much (100 GB), and the returns slot in
the front door is a live address the public still uses (mail-enabled folders)** — board that slot up
and post piles on the pavement.

**The one line:** ⭐ **One writable hierarchy, content homed per mailbox, and the mail-enabled
folders are live mail flow.**

---

## 10. Self-test

1. How many writable copies of the hierarchy exist?
   → ⭐ Exactly one, in the primary public folder mailbox.
2. Why can a public folder tree not span two public folder mailboxes?
   → ⭐ Content is homed to a single mailbox per folder; the map assigns whole folders.
3. What is the size limit per public folder mailbox?
   → **100 GB** (⚠ verify currency).
4. Why size the map to 50 GB rather than 100 GB?
   → ⭐ Headroom; rebalancing later is far more disruptive.
5. Which public folder finding is a mail-flow dependency?
   → ⭐ Mail-enabled folders with external SMTP addresses.
6. Why can public folders not be migrated in waves?
   → ⭐ The source hierarchy is locked read-only at finalisation; there is no partial state.
7. A customer says they do not use public folders. What do you do?
   → ⭐ Run `Get-PublicFolder -Recurse` anyway. They are usually wrong.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `pf-stats.csv` and the generated `pf-map.csv`, with the sizing decision explained |
| `security` | the folder permission export, showing any `Default = Owner` findings |
| `operations` | source vs target folder counts, and the mail-enabled address list verified post-cutover |
| `break-fix` | one bounced message to a mail-enabled folder and the resolution |
| `architecture-decisions` | ⭐ the per-tree decision: migrate, convert to shared mailbox, or delete |

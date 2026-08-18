# Discovery and Assessment

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Every failed migration was mis-scoped, not mis-executed.** Pairs with
> [`../migration-tools/`](../migration-tools/) and
> [`../../75-architecture-and-consulting/discovery/`](../../75-architecture-and-consulting/discovery/).

---

## 1. What it is

Discovery is the measured inventory of the source estate taken **before** a migration design
exists: how many mailboxes, how large, how old, who delegates to whom, which public folders are
mail-enabled, which SharePoint paths exceed the URL limit. Assessment turns that inventory into
**numbers that constrain the schedule**.

⭐ **The deliverable is not a document. It is a date, and a list of things that cannot move.**

---

## 2. Why it exists

Before it, migrations were scoped from the customer's answer to *"how many users do you have?"* —
a number that is wrong in every direction at once:

| The customer says | Discovery finds | Effect on the plan |
|---|---|---|
| "About 400 users" | 400 licensed, ⭐ **517 mailboxes** | shared, room, equipment, disabled-but-retained are real data |
| "Nothing big" | one **340 GB** archive | ⭐ **one mailbox becomes the critical path** |
| "We don't use public folders" | 14 GB, ⭐ **6 mail-enabled** | an entire extra workstream |
| "Just email" | 2.1 TB of file shares | doubles the project |

⭐ **The cost of skipping discovery is not a bad estimate — it is a cutover weekend that does not
end.** The item that overruns is always one nobody counted.

---

## 3. How it works underneath

Three independent passes, because the three data planes do not share an inventory:

```
① IDENTITY    Entra / AD          users, groups, service accounts,
                                  ⭐ objects that authenticate but are not people
     │
② MAILBOX     Exchange            size, item count, delegates, forwarding,
     │                            ⭐ litigation hold, archive, public folders
     │
③ CONTENT     SharePoint/OneDrive sites, storage, versions,
     │                            ⭐ path length, invalid characters, checked-out files
     ▼
  CONSTRAINT SET  →  wire time · blockers · waves
```

⭐ **The constraint that decides the schedule is almost always ③, or one outlier in ②** — never the
headline user count.

---

## 4. Worked example — turning an inventory into a date

Source: **517 mailboxes, 3.4 TB**. Uplink **200 Mbit/s**, of which you plan to use **60 %**.

```
200 Mbit/s x 0.60 = 120 Mbit/s = 15 MB/s
3.4 TB            = 3,481,600 MB
3,481,600 / 15    = 232,107 s  = 64.5 hours of pure wire time
```

⭐ **Then the two multipliers everyone forgets:**

| Factor | Multiplier | Why |
|---|---|---|
| Microsoft-side throttling | ⭐ **x 1.5 – 3** | EXO throttles per-mailbox move throughput; you do not control it |
| Item-count overhead | x 1.2 | many small items move far slower per MB than few large ones |

```
64.5 h  x 2  x 1.2  =  ⭐ ~155 hours  ≈ 6.5 days of continuous sync
```

⭐ **This arithmetic chooses the migration type — not preference.** 6.5 days of sync is impossible
in a cutover weekend and trivial as a background pre-seed, which is exactly the case for hybrid.

⚠ `⚠ check` — per-mailbox move throughput in EXO is commonly observed at **0.3–1.0 GB/hour** and is
not contractual. Measure it in a pilot; never quote it from a blog.

---

## 5. Commands

**Mailbox inventory, with the fields that change the plan** (source Exchange):

```powershell
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $s = Get-MailboxStatistics $_.Identity
    [pscustomobject]@{
        UPN     = $_.UserPrincipalName
        Type    = $_.RecipientTypeDetails
        SizeGB  = [math]::Round(($s.TotalItemSize.Value.ToBytes()/1GB),2)
        Items   = $s.ItemCount
        Archive = $_.ArchiveStatus
        Hold    = $_.LitigationHoldEnabled
        Forward = $_.ForwardingSmtpAddress
    }
} | Export-Csv .\mailbox-inventory.csv -NoTypeInformation
```

Expected shape:

```
UPN                  Type           SizeGB  Items   Archive  Hold   Forward
j.smith@contoso.com  UserMailbox      4.71   38211  Active   False
finance@contoso.com  SharedMailbox   61.30  402118  None     True
```

⭐ **Sort by `SizeGB` descending and read the top ten rows. That is the critical path** — usually
two or three mailboxes.

**The delegation map — what breaks silently after cutover:**

```powershell
Get-Mailbox -ResultSize Unlimited | Get-MailboxPermission |
  Where-Object { $_.User -notlike 'NT AUTHORITY\*' -and -not $_.IsInherited } |
  Select-Object Identity, User, AccessRights |
  Export-Csv .\delegation.csv -NoTypeInformation
```

⭐ **If the delegate moves in wave 1 and the mailbox in wave 4, the delegate loses access for three
weeks.** Nobody wrote it down, because it worked yesterday. See [`../coexistence/`](../coexistence/) §4.

**SharePoint pre-scan** — the SharePoint Migration Assessment Tool:

```powershell
.\SMAT.exe -SiteUrl https://contoso.sharepoint.com -ScanMode Full
```

Per-check CSVs. ⭐ **The three that matter:** `PathLength`, `InvalidCharacters`, `CheckedOutFiles`.

**Total content, cheaply, from the tenant side:**

```powershell
Get-SPOSite -Limit All | Measure-Object StorageUsageCurrent -Sum |
  Select-Object @{n='TotalGB';e={[math]::Round($_.Sum/1024,1)}}
```

```
TotalGB
-------
 2148.6
```

---

## 6. When and where

| Situation | Depth of discovery |
|---|---|
| < 50 users, mail only | one afternoon — the inventory CSV is enough |
| ⭐ **Any tenant-to-tenant** | ⭐ **full: identity, mailbox, content, app registrations** |
| Regulated customer | ⭐ **hold and retention inventory before anything else** |
| Google Workspace source | add Drive sizing and shared-drive ownership — [`../google-workspace-to-m365/`](../google-workspace-to-m365/) |

⭐ **The one question that reorders the project: "is anything on legal hold?"** A mailbox on
litigation hold cannot be deleted from the source after the move, which changes decommissioning,
licence spend, and the engagement end date.

---

## 7. What breaks

| Symptom | Real cause | Diagnosis |
|---|---|---|
| Estimate wrong by 3x | measured GB, ⭐ **not item count** | 400,000 small items move slower than one 40 GB PST |
| "Where did the meeting rooms go?" | counted `UserMailbox` only | filter `RecipientTypeDetails`, not licence count |
| Shared mailbox access lost mid-project | delegation not mapped to waves | `delegation.csv` joined to the wave plan |
| SPMT fails thousands of files | path > **400** characters | ⭐ SMAT `PathLength` — knowable in advance |
| `The term 'Get-SPOSite' is not recognized` | module missing | `Install-Module Microsoft.Online.SharePoint.PowerShell` |

⭐ **400 is the SharePoint Online limit for the entire decoded URL path** — server-relative path plus
file name. Deep nesting under a long site name consumes it before the user does. ⚠ check the figure
against current Microsoft limits documentation at engagement time.

---

## 8. Customer discovery questions

1. ⭐ **"Is any mailbox or site on litigation hold or under a retention policy?"**
2. "How many mailboxes are shared, room, or equipment — not people?"
3. "Which mailboxes does anyone other than the owner open?"
4. "Do you use public folders? Are any mail-enabled?" (⭐ they will say no — check anyway)
5. "What is the largest single mailbox, and who owns it?"
6. ⭐ **"What is your upload bandwidth, and may we use it overnight?"**
7. "Are file shares or a third-party archive in scope?"
8. "Which applications send mail through the current server?" (⭐ the printers and the ERP)

---

## 9. Remember it

**Hook — `I M C`: Identity, Mailbox, Content.** Three inventories, three tools, one constraint set.

**Analogy — the removals quote.** A firm that asks "how many rooms?" gives a wrong price. The one
that walks the house asks about the piano, the loft, and whether the van can park. ⭐ **The piano is
the 340 GB archive, the parking is your bandwidth, the loft is public folders.** The analogy
predicts the failure: **the item nobody walked past is the one that overruns.**

**The one line:** ⭐ **Discovery converts a user count into a date and a list of blockers.**

---

## 10. Self-test

1. Why is total GB a worse predictor than item count?
   → ⭐ MRS and SPMT are transaction-bound; per-item overhead dominates.
2. Three reasons mailbox count exceeds user count?
   → Shared/room/equipment; disabled-but-retained; archive mailboxes.
3. SharePoint Online full-path character limit?
   → **400** decoded characters.
4. Why does litigation hold change the plan?
   → ⭐ Source mailbox cannot be deleted — decommissioning and licence spend continue.
5. Pilot moves 1 GB in 70 minutes. Estimate 3.4 TB single-threaded.
   → ~4,000 hours — ⭐ which proves you must parallelise. That is what migration batches are for.
6. Which artifact prevents the "shared mailbox disappeared" ticket?
   → The delegation map joined to the wave plan.
7. Why run SMAT before design rather than before cutover?
   → ⭐ Path-length remediation is **customer** work, with a lead time.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | `mailbox-inventory.csv` and `delegation.csv` from a real or seeded tenant |
| `operations` | the wire-time calculation for a stated bandwidth, both multipliers shown |
| `break-fix` | an SMAT `PathLength` report with at least one over-limit path |
| `customer-use-cases` | the eight questions, answered for one scenario |
| `architecture-decisions` | ⭐ the memo choosing cutover vs hybrid **from the arithmetic** |

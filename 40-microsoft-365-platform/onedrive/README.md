# OneDrive for Business

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **A SharePoint site per user** — everything in
> [`../sharepoint-online/`](../sharepoint-online/) applies, plus one property that changes the risk
> entirely: **it has a single owner, and that owner leaves.**

---

## 1. ⭐ What makes it different from SharePoint

**Technically it is a SharePoint site collection. Organisationally it is the opposite of one:**

| | Team site | ⭐ OneDrive |
|---|---|---|
| Owner | a group, several people | ⭐ **one person** |
| Purpose | shared by design | ⭐ **personal by default, shared by accident** |
| Governance | site lifecycle, labels | ⭐ **usually none** |
| On leaver | site persists | ⭐ **deleted on a timer** |
| Content | what people meant to share | ⭐ **what they were working on** |

⭐ **That last row is the security point.** A team site holds the finished, sanctioned version. **A
OneDrive holds the draft of the redundancy list, the export "just to check something", and the
spreadsheet somebody built because the real system was slow.** It is where the sensitive data is
*before* anyone decided how sensitive it was.

---

## 2. ⭐ The two-sided exfiltration path

**OneDrive is the most common egress route in M365, and it works in both directions:**

```
OUT   corporate file → ⭐ synced to a personal device → outside your control
IN    personal file  → ⭐ uploaded into corporate storage → now your liability
OUT   corporate file → shared by link → ⭐ forwarded, no sign-in
```

⭐ **The sync client is the part people forget.** A file that never left via email or a share link can
be sitting in a folder on an unmanaged home laptop, because the user signed in to the sync client once
and everything followed.

**The controls, and they are ordinary:**

| Control | ⭐ What it actually stops |
|---|---|
| ⭐ **CA: block download on unmanaged devices** | browser access becomes view-only |
| ⭐ **Restrict sync to domain-joined / compliant devices** | ⭐ the sync path, closed |
| **Known Folder Move** | Desktop/Documents into OneDrive — ⭐ good for backup, ⭐ widens what syncs |
| **DLP on OneDrive** | policy-based blocking of sensitive content |
| **Sharing controls** | inherited from [`../sharepoint-online/`](../sharepoint-online/) §4 |

⚠ **Known Folder Move is dual-edged and rarely discussed as such.** It genuinely protects against
device loss — and it means **everything a user saves to their Desktop is now in the corporate cloud
and in the Copilot-indexable corpus.** That is a data-classification consequence dressed as a backup
feature.

---

## 3. ⭐ The leaver problem — the finding this topic exists for

> **When an account is deleted, its OneDrive is retained for a configurable period (default **30
> days**) and then permanently deleted.**

⭐ **So the leaver's OneDrive is simultaneously your biggest eDiscovery exposure and your most
frequent accidental data loss** — and both failure modes come from the same setting nobody reviews.

```
Person leaves
   ├─ ⚠ nobody knows what was in their OneDrive
   ├─ ⭐ retention timer starts
   ├─ manager gets access… if someone configured a delegate
   └─ ⭐ day 31: gone — including the only copy of something
```

```powershell
Connect-MgGraph -Scopes 'Sites.Read.All','User.Read.All','Directory.Read.All'

# ⭐ Disabled/blocked accounts that still have a OneDrive, and how long it has left
Get-MgUser -All -Filter 'accountEnabled eq false' -Property Id,DisplayName,UserPrincipalName |
  ForEach-Object {
    $od = Get-MgUserDefaultDrive -UserId $_.Id -EA SilentlyContinue
    if ($od) {
      [pscustomobject]@{
        User    = $_.UserPrincipalName
        SizeGB  = [math]::Round($od.Quota.Used / 1GB, 2)
        Modified= $od.LastModifiedDateTime
      }
    }
  } | Sort-Object SizeGB -Descending | Select-Object -First 15
```

```
User                        SizeGB  Modified
--------------------------  ------  ----------
r.shaw@contoso.com           41.20  2026-05-02      <-- ⚠⚠ 41 GB, owner gone
a.patel@contoso.com          12.80  2026-06-19      <-- ⚠ what is in here?
```

⭐ **41 GB belonging to nobody is not a storage finding — it is unclassified, unowned corporate data
with a delete timer on it.** Nobody can say whether it contains regulated content, nobody has
reviewed its sharing links, and **the sharing links still work after the owner is disabled.**

> ⭐ **That is the detail worth carrying: disabling an account does not revoke the anonymous links
> that account created.** The link is a bearer token
> ([`../sharepoint-online/`](../sharepoint-online/) §2); it does not care that the issuer has left.

**The fix is a leaver runbook, not a setting:**

```
① ⭐ BEFORE disabling: enumerate sharing links from that OneDrive and revoke
② Apply a retention policy or legal hold if the content may be needed
③ Delegate access to the manager, with an expiry
④ ⭐ Decide deliberately: archive or delete — do not let the timer decide
```

---

## 4. Worked example — what is being shared out of OneDrive

```powershell
# ⭐ External and anonymous sharing originating in personal storage
$users = Get-MgUser -All -Property Id,UserPrincipalName |
         Select-Object -First 200        # ⚠ page in batches; this is expensive

foreach ($u in $users) {
  $drive = Get-MgUserDefaultDrive -UserId $u.Id -EA SilentlyContinue
  if (-not $drive) { continue }
  $items = Get-MgDriveRootChild -DriveId $drive.Id -EA SilentlyContinue
  foreach ($i in $items) {
    $perms = @(Get-MgDriveItemPermission -DriveId $drive.Id -DriveItemId $i.Id -EA SilentlyContinue)
    foreach ($p in $perms) {
      if ($p.Link.Scope -in 'anonymous','organization') {
        [pscustomobject]@{
          Owner = $u.UserPrincipalName; Item = $i.Name
          Scope = $p.Link.Scope; Type = $p.Link.Type
          Expires = $p.ExpirationDateTime ?? '⚠ never'
        }
      }
    }
  }
}
```

```
Owner                  Item                          Scope        Type   Expires
---------------------  ----------------------------  -----------  -----  --------
j.doe@contoso.com      2026 Salary Bands.xlsx        anonymous    edit   ⚠ never
r.shaw@contoso.com     Customer Export.csv           anonymous    view   ⚠ never
```

⭐ **Row one is `anonymous` + `edit` + never expires, on salary data**, created by someone who wanted
a colleague to look at it quickly. **No policy was violated at the moment of creation** — the tenant
permitted it, the button was there, and the file is now editable by anyone holding a URL.

⚠ **This enumeration is slow at tenant scale.** ⭐ **Use the SharePoint admin centre's Data Access
Governance "Sharing links" report first** ([`../sharepoint-online/`](../sharepoint-online/) §3) and
use Graph to investigate specifics.

---

## 5. What breaks

**Treating OneDrive as out of scope.** §1 — ⭐ it holds the pre-classification data.

**No sync restriction.** §2 — corporate files on unmanaged home devices.

**Known Folder Move enabled without classification thought.** §2 — ⭐ the Desktop is now indexed.

**Leaver OneDrives left to the timer.** §3 — ⭐ deletion by default, at day 31.

**Not revoking sharing links before disabling an account.** §3 — ⭐ links outlive the owner.

**Assuming account disable revokes access.** §3 — anonymous links are bearer tokens.

**No delegate on a leaver's OneDrive.** §3 — content becomes unreachable and then gone.

**Enumerating with Graph at tenant scale.** §4 — use the admin centre reports first.

**Anonymous edit links never reviewed.** §4.

**Excluding OneDrive from DLP and retention** while including SharePoint — same substrate, different
policy scope, and the gap is where people work.

---

## 6. Customer discovery questions

1. Is **sync restricted** to compliant or domain-joined devices? *(§2.)*
2. Is **Known Folder Move** on — and was the classification consequence considered? *(§2.)*
3. What is the **OneDrive retention period** after account deletion, and who decided it? *(§3.)*
4. Does the **leaver process** revoke sharing links **before** disabling the account? *(§3.)*
5. How many **disabled accounts** still have OneDrive content, and how much? *(§3 — run it.)*
6. How many **anonymous edit** links exist in personal storage? *(§4.)*
7. Is **DLP** scoped to OneDrive as well as SharePoint and Exchange?
8. Can you download to an **unmanaged device** right now?
9. ⭐ Who reviews what a leaver's OneDrive contained before it is deleted?

---

## 7. Remember it

**Hook — "A SharePoint site with one owner, and the owner leaves."**

**Analogy — the desk drawer, not the filing cabinet.** ⭐ The filing cabinet holds what the company
decided to keep; **the desk drawer holds the working copy, the printout somebody took home, and the
list they were told not to make.** When the person leaves, the company empties the cabinet carefully
and ⭐ **throws the drawer in a skip after thirty days without opening it** — having never asked what
was in there. **And the keys they cut for the drawer still work**, because a key does not know its
owner resigned.

**The one thing:** ⭐ **disabling an account does not revoke the anonymous sharing links that account
created.** The link is a bearer token — it authenticates the URL, not the person — so a leaver's
"Anyone with the link" share on a customer export keeps working indefinitely after their access is
gone, and no offboarding checklist that stops at "disable the account" will catch it. **Revoke links
before you disable, and put that step in the runbook**, because it is the one action nobody thinks to
take and nothing else will surface it.

**Runner-up:** ⭐ **Known Folder Move puts everyone's Desktop into the Copilot-indexable corpus.** Good
backup, real classification consequence.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. What is OneDrive technically, and what makes it organisationally different?
2. ⭐ Why does a OneDrive hold more sensitive content than a team site, in practice?
3. Name the three exfiltration directions and the control for each.
4. ⭐ Why is Known Folder Move dual-edged?
5. What happens to a OneDrive when the account is deleted, and on what timer?
6. ⭐ Does disabling an account revoke sharing links it created? Why or why not?
7. List the four steps of a correct leaver runbook.
8. Why should you use the admin centre reports before Graph? *(§4.)*
9. What is the worst combination of link properties, and why does it usually happen?
10. Why is excluding OneDrive from DLP a specific mistake?

<details>
<summary>Answers</summary>

1. ⭐ A **SharePoint site collection per user**. Organisationally: ⭐ **one owner, no governance, and
   the owner eventually leaves.**
2. ⭐ It holds data **before anyone decided how sensitive it was** — drafts, exports, working copies.
3. **Out via sync** (restrict sync to compliant/domain-joined devices), **in via upload** (DLP,
   policy), **out via link** (sharing controls, CA download block).
4. ⭐ It protects against device loss **and** puts everything on every Desktop into corporate storage
   and the **Copilot-indexable corpus**.
5. It is **retained for a configurable period, default 30 days**, then permanently deleted.
6. ⭐ **No.** An anonymous link is a ⭐ **bearer token** — it authenticates the URL, not the person.
7. ⭐ **Revoke sharing links → apply retention/hold if needed → delegate access with an expiry →
   decide archive or delete deliberately.**
8. ⭐ Graph enumeration is **slow at tenant scale**; the **Data Access Governance** reports
   pre-compute the link inventory.
9. ⭐ **`anonymous` + `edit` + never expires.** It happens because someone wanted a colleague to look
   at something quickly and the tenant permitted it.
10. ⭐ It is the **same substrate** as SharePoint but the **place people actually work**, so a
    DLP scope that covers SharePoint and Exchange and not OneDrive has a hole exactly where the
    unclassified data is.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** ⭐ — the §3 disabled-account sweep and the §4 sharing enumeration (batched).
  **Runnable today on the E5 licence.**
- **`break-fix/`** ⭐ — create an **anonymous edit link** from a OneDrive, **disable that account**,
  then open the link in a private window and **edit the file**. ⭐ **That is the whole topic in ninety
  seconds, and nobody who watches it forgets it.** Then revoke the link and show the failure.
- **`security/`** — sync restriction state; leaver OneDrive inventory with sizes and ages; anonymous
  edit links in personal storage; DLP scope coverage including OneDrive.
- **`operations/`** — leaver runbook with ⭐ **revoke-links-before-disable** as step one; delegate
  assignment with expiry; explicit archive-or-delete decision rather than the timer.
- **`architecture-decisions/`** — ADR: sync restricted to compliant devices; Known Folder Move enabled
  ⭐ with the classification consequence recorded and accepted.
- **`customer-use-cases/`** — §6 answered; "41 GB belonging to nobody, deleting on day 31" as the
  headline finding.

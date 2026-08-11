# Microsoft Teams

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **A user interface over [`../microsoft-365-groups/`](../microsoft-365-groups/),
> [`../sharepoint-online/`](../sharepoint-online/) and
> [`../exchange-online/`](../exchange-online/)** — which is why "securing Teams" is mostly securing
> those three.

---

## 1. Where Teams data actually lives

```
Channel conversations   →  ⭐ the Group MAILBOX (hidden folder)
Chat (1:1 and group)    →  ⭐ EACH PARTICIPANT'S mailbox (hidden folder)
Files in a channel      →  ⭐ the Group's SHAREPOINT site
Files in a chat         →  ⭐ the SENDER'S ONEDRIVE
Meeting recordings      →  ⭐ organiser's OneDrive, or the channel site
Private channel files   →  ⭐ a SEPARATE SharePoint site
```

⭐ **"Files in a chat live in the sender's OneDrive" is the line that catches people.** Sharing a
document in a private chat creates a sharing link from **your personal storage** — so
[`../onedrive/`](../onedrive/) §3 applies: **when you leave, that file's home is on a deletion timer,
and the link you created outlives your account.**

⭐ **And a private channel gets its own SharePoint site with its own membership** — so a review of the
parent team's permissions **does not cover it.** Shared channels do the same. **Any Teams permission
audit that enumerates only the parent site is incomplete by design.**

---

## 2. ⭐ External access vs guest access — the distinction that matters

**Two different features, routinely conflated, with very different risk:**

| | **External access** (federation) | ⭐ **Guest access** |
|---|---|---|
| What it is | chat/call with another **tenant** | ⭐ an account **in your directory** |
| Object created | ⭐ **none** | ⭐ **a guest user object** |
| Can join a Team? | ⚠ no (chat only) | ⭐ **yes — sees files, chat, members** |
| Governed by | domain allow/block list | ⭐ CA, access reviews, entitlement management |
| Lifecycle | none needed | ⭐ **must be reviewed and expired** |

⭐ **Guest access creates a real principal in your tenant** — which is *good*, because it means every
identity control you own applies: Conditional Access, access reviews, entitlement management, sign-in
logs. ⭐ **External access creates nothing, so nothing governs it beyond the domain list.**

> ⭐ **The counter-intuitive conclusion, and the one worth stating in a review:** *guest access is the
> more governable of the two.* People instinctively fear the guest object and permit open federation,
> when the guest is the one you can see, review and expire.

⚠ **Guests accumulate.** A guest invited for a two-week project is still a member of your directory
three years later — [`../../30-identity-and-nhi/external-identities/`](../../30-identity-and-nhi/external-identities/).
**Access reviews on guest membership are the control, and they are not on by default.**

---

## 3. Worked example — the guest and channel audit

```powershell
Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All','Directory.Read.All'

# ① ⭐ Guests, and how long they have been here
$guests = Get-MgUser -All -Filter "userType eq 'Guest'" `
  -Property Id,DisplayName,Mail,CreatedDateTime,SignInActivity

$guests | Select-Object DisplayName, Mail,
  @{n='AgeDays';e={ [int]((Get-Date) - [datetime]$_.CreatedDateTime).TotalDays }},
  @{n='LastSignIn';e={ $_.SignInActivity.LastSignInDateTime ?? '⚠ never' }} |
  Sort-Object AgeDays -Descending | Select-Object -First 15
```

```
DisplayName        Mail                       AgeDays  LastSignIn
-----------------  -------------------------  -------  -----------
Consultant A       a@partner.example             1204  ⚠ never
Vendor Support     s@vendor.example               892  2024-03-11    <-- ⚠⚠ 2 years idle
```

⭐ **`never` signed in, 1,204 days old, still a member of Teams** — a directory object that has never
been used and has never been reviewed. **It is not an attack; it is an unclosed door**, and it is what
an access review exists to find.

```powershell
# ② ⭐ Guests in teams whose files are sensitive - the join that produces a finding
Get-MgGroup -All -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" `
  -Property Id,DisplayName,Visibility | ForEach-Object {
    $g = $_
    $guestMembers = @(Get-MgGroupMember -GroupId $g.Id -All -EA SilentlyContinue |
      Where-Object { $_.AdditionalProperties.userType -eq 'Guest' })
    if ($guestMembers.Count) {
      [pscustomobject]@{
        Team = $g.DisplayName; Visibility = $g.Visibility
        Guests = $guestMembers.Count
        Names = (($guestMembers.AdditionalProperties.displayName) -join '; ')
      }
    }
  } | Sort-Object Guests -Descending | Select-Object -First 10
```

⭐ **Then the part most audits miss — private and shared channels have their own sites:**

```powershell
# ③ ⭐ Private/shared channels: separate membership, separate SharePoint site
Get-MgGroup -All -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" | ForEach-Object {
  $t = $_
  Get-MgTeamChannel -TeamId $t.Id -EA SilentlyContinue |
    Where-Object { $_.MembershipType -in 'private','shared' } |
    ForEach-Object {
      [pscustomobject]@{ Team=$t.DisplayName; Channel=$_.DisplayName; Type=$_.MembershipType }
    }
}
```

⭐ **Every row is a SharePoint site that a parent-team permission review did not cover.** Shared
channels are the sharper case: **they can be shared with an entire external tenant**, so the
membership is not even fully enumerable from your side.

---

## 4. Meetings — the surface nobody reviews

| Setting | ⭐ Why it matters |
|---|---|
| ⭐ **Lobby: who bypasses** | "Everyone" means ⭐ **anyone with the link joins unannounced** |
| **Anonymous join** | no identity at all in the participant list |
| ⭐ **Recording + transcription** | ⭐ creates a permanent, searchable, **Copilot-indexable** artifact |
| **Who can present** | screen-share hijack is real |
| **Meeting chat retention** | lives in mailboxes, subject to eDiscovery |

⭐ **A recorded, transcribed meeting is a new document containing everything anyone said**, stored in
the organiser's OneDrive, shared with attendees by link, and **indexed for Copilot**. It is created by
clicking one button, classified by nobody, and it is frequently the most sensitive object produced
that week.

⭐ **Sensitivity labels on meetings** (via the container label,
[`../microsoft-365-groups/`](../microsoft-365-groups/) §5) can force lobby behaviour, block recording
and prevent copying chat — **one label, several controls**, which is the same leverage argument as
container labels on sites.

---

## 5. Apps, bots and the third-party surface

```
Teams app  →  requests Graph permissions  →  ⭐ consented by a USER, or by an admin
           →  ⭐ often reads channel messages and files
```

⭐ **A Teams app is an Entra app registration with a UI** — everything in
[`../../30-identity-and-nhi/app-registrations/`](../../30-identity-and-nhi/app-registrations/) applies,
including the delegated-versus-application permission distinction that decides blast radius. ⚠ **If
user consent is unrestricted, a user can grant an app access to their chats and files.**

⭐ **The control is an app permission policy plus admin consent workflow** — not blocking apps, which
pushes people to unmanaged alternatives. **Same trade as everywhere else in this repo: provide a
governed path or lose visibility.**

---

## 6. What breaks

**Auditing the parent team only.** §3 — ⭐ private and shared channels have their own sites.

**Conflating external access with guest access.** §2 — different objects, different governance.

**Open federation because guests "feel riskier".** §2 — ⭐ the guest is the governable one.

**Guests never reviewed.** §3 — ⭐ `never` signed in, three years old, still a member.

**Assuming chat files live in the Team.** §1 — ⭐ they live in the **sender's OneDrive**.

**Lobby bypass set to Everyone.** §4 — anyone with the link joins.

**Recordings unclassified.** §4 — ⭐ a permanent, searchable, indexed artifact.

**Unrestricted user consent for Teams apps.** §5.

**Blocking apps outright.** §5 — unmanaged alternatives, no visibility.

**Treating Teams as a product to secure** rather than a view over three others. §1.

---

## 7. Customer discovery questions

1. Do you have **guest access**, **external access**, or both — and can the team explain the
   difference? *(§2.)*
2. How many guests exist, how old are they, and how many have ⭐ **never signed in**? *(§3.)*
3. Are there **access reviews** on guest membership?
4. Have you enumerated **private and shared channels** and their sites? *(§3.)*
5. Are any channels **shared with an external tenant**?
6. What is the **lobby** default, and is **anonymous join** permitted? *(§4.)*
7. Who can **record**, and where do recordings land — are they labelled? *(§4.)*
8. Is **user consent** for Teams apps restricted, with an admin consent workflow? *(§5.)*
9. ⭐ Do people know chat files live in the **sender's OneDrive**? *(§1.)*

---

## 8. Remember it

**Hook — "Teams is a window, not a room."** The data is in Groups, SharePoint and Exchange.

**Analogy — a lobby with several doors and one visitors' book.** ⭐ **Guest access signs people into
the visitors' book** — you know who they are, when they came, and you can strike them off. ⭐
**External access lets people talk through the intercom without signing anything** — lower risk in
one sense, and completely unreviewable in another. **And the private channel is a side room with its
own lock that isn't on the building plan**, so the security walk-through misses it entirely.

**The one thing:** ⭐ **guest access is the more governable option, and organisations instinctively
choose the opposite.** A guest is a real principal in your directory: Conditional Access applies,
access reviews can expire them, sign-in logs record them, entitlement management can package their
access. External federation creates nothing to review. **Teams that fear the guest object and permit
open federation have chosen the ungovernable path for the safe-feeling reason** — and saying so, with
the reasoning, is exactly the sort of judgement a review is paying for.

**Runner-up:** ⭐ **files shared in a chat live in the sender's OneDrive**, so they inherit the leaver
problem from [`../onedrive/`](../onedrive/) §3.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Where do channel messages, chat messages, channel files and chat files each live?
2. ⭐ Why does a private channel break a permissions audit?
3. Distinguish external access from guest access on four axes.
4. ⭐ Which is more governable, and why is that counter-intuitive?
5. What does an access review on guests actually catch?
6. Why is a meeting recording a data-classification event?
7. What can a container sensitivity label enforce on meetings?
8. What is a Teams app, in Entra terms?
9. Why is blocking Teams apps outright the wrong control?
10. ⭐ A user leaves — what happens to the files they shared in chats?

<details>
<summary>Answers</summary>

1. Channel messages → **the Group mailbox**; chat messages → ⭐ **each participant's mailbox**;
   channel files → **the Group's SharePoint site**; ⭐ chat files → **the sender's OneDrive**.
2. ⭐ It has its **own SharePoint site and own membership**, so a review of the parent team's
   permissions does not cover it. Shared channels too.
3. **What it is** (tenant federation vs a directory account), **object created** (none vs ⭐ a guest
   user), **can join a Team** (no vs ⭐ yes), **governance** (domain list vs ⭐ CA, access reviews,
   entitlement management).
4. ⭐ **Guest access** — it creates a principal you can see, review, condition and expire. It is
   counter-intuitive because the guest *object* feels like the risk, while federation feels lighter.
5. ⭐ Guests who have **never signed in** or have been idle for years and are still team members.
6. ⭐ It creates a **permanent, searchable, Copilot-indexable artifact** of everything said, stored in
   the organiser's OneDrive and classified by nobody.
7. ⭐ **Lobby behaviour, recording prevention, and copy restrictions on chat** — one label, several
   controls.
8. ⭐ **An Entra app registration with a UI** — delegated vs application permissions decide blast
   radius.
9. It pushes people to **unmanaged alternatives**, removing visibility. Use ⭐ **app permission
   policies plus an admin consent workflow**.
10. ⭐ Those files live in **their OneDrive**, which goes on a deletion timer — and ⭐ **the sharing
    links they created keep working after the account is disabled.**

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 guest inventory with ages and last sign-in, plus the private/shared channel
  enumeration. **Runnable today on the E5 licence.**
- **`break-fix/`** ⭐ — create a **private channel**, put a file in it, then run a permissions audit
  against the **parent team** and show the file does not appear. **That gap is the topic's core
  finding and it takes five minutes to demonstrate.** Then share a file in a 1:1 chat and locate it in
  the sender's OneDrive.
- **`security/`** — guest register with age, last sign-in and team membership; private/shared channel
  site inventory; external federation domain list; meeting policy (lobby, anonymous join, recording);
  Teams app consent posture.
- **`operations/`** — guest access reviews on a cadence; recording retention and labelling; admin
  consent workflow with an owner.
- **`architecture-decisions/`** — ADR: ⭐ guest access preferred over open federation, **with the
  governability argument recorded**; container labels enforce meeting controls.
- **`customer-use-cases/`** — §7 answered; "guests who have never signed in" as a standalone finding.

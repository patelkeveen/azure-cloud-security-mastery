# SharePoint Online

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **The storage substrate for the whole platform** — Teams files, OneDrive, Loop and Copilot's
> grounding corpus all live here. Read [`../microsoft-365-groups/`](../microsoft-365-groups/) first.

---

## 1. ⭐ Where the data actually is

```
Teams "Files" tab      →  ⭐ a SharePoint document library
OneDrive for Business  →  ⭐ a SharePoint site (one per user)
Loop / Lists / Forms   →  SharePoint underneath
⭐ Copilot's grounding  →  ⭐ this, indexed
```

⭐ **So a SharePoint permission review *is* the M365 data-security review.** Teams, OneDrive and
Copilot are surfaces; **this is the store**, and the finding in
[`../../60-ai-and-secure-ai/sensitive-data-leakage/`](../../60-ai-and-secure-ai/sensitive-data-leakage/)
§2 is a SharePoint finding wearing an AI hat.

---

## 2. ⭐ Four ways access is granted, and only one is visible

**This is the topic's core, and the reason SharePoint permission audits are hard:**

| Path | Where it shows | ⭐ Risk |
|---|---|---|
| ① **Site membership** via the M365 Group | Group members | visible, reviewable |
| ② **Direct site permissions** (SharePoint groups) | Site permissions | ⚠ bypasses the Group |
| ③ ⭐ **Sharing links** | ⭐ **per item, invisible from the site view** | ⭐ **the real exposure** |
| ④ **Item-level unique permissions** | broken inheritance | ⚠ silently divergent |

⭐ **Paths ③ and ④ are where over-sharing lives, and neither appears when you look at "who is a member
of this site".** That is why an audit that lists site members reports a clean estate over a corpus
that is in fact widely shared.

**The link types, in severity order:**

```
⭐ "Anyone with the link"   ANONYMOUS. No sign-in. Forwardable. ⭐ Indexable if it leaks.
   "People in <org>"        any authenticated tenant user — including guests, sometimes
   "People with existing access"  ⭐ safe: grants nothing new
   "Specific people"        named, auditable
```

⭐ **"Anyone" links are the single highest-severity object in M365**, because they defeat every
identity control you own: no Conditional Access, no MFA, no device compliance, no named principal in
the audit log. **They are the M365 equivalent of an API key** —
[`../../60-ai-and-secure-ai/azure-openai/`](../../60-ai-and-secure-ai/azure-openai/) §3 — *"does the
caller hold the string?"* rather than *"who is the caller?"*

> ⭐ **That parallel is the one to carry into an interview:** anonymous sharing links, storage account
> shared keys, and AI API keys are the same failure in three products — **a bearer secret standing in
> for an identity.**

---

## 3. Worked example — find the exposure

```powershell
Connect-MgGraph -Scopes 'Sites.Read.All','Files.Read.All'

# ① ⭐ Tenant-level: is anonymous sharing even possible?
#    (SharePoint admin: SharingCapability)
#    ExternalUserAndGuestSharing = ⭐ "Anyone" links ALLOWED
Get-MgBetaAdminSharepointSetting |
  Select-Object SharingCapability, SharingDomainRestrictionMode,
                AnonymousLinkExpirationInDays, DefaultSharingLinkType
```

```
SharingCapability              : ExternalUserAndGuestSharing   <-- ⚠ anonymous permitted
SharingDomainRestrictionMode   : None                          <-- ⚠ any domain
AnonymousLinkExpirationInDays  : 0                             <-- ⚠⚠⚠ never expires
DefaultSharingLinkType         : Internal
```

⭐ **`AnonymousLinkExpirationInDays = 0` is the finding.** A link created in 2021 by someone who has
since left still works today, has never been reviewed, and grants access with no sign-in. **Setting
an expiry is one field and it retroactively bounds every future link** — ⚠ though not existing ones,
which need a separate sweep.

```powershell
# ② ⭐ The org-wide grants that feed Copilot exposure
$orgWide = 'Everyone','Everyone except external users'

Get-MgSite -Search '*' -All | ForEach-Object {
  $site = $_
  $perms = @(Get-MgSitePermission -SiteId $site.Id -EA SilentlyContinue)
  foreach ($p in $perms) {
    $who = "$($p.GrantedToIdentitiesV2.SiteGroup.DisplayName)$($p.GrantedToIdentitiesV2.User.DisplayName)"
    if ($who -in $orgWide) {
      [pscustomobject]@{ Site=$site.DisplayName; Url=$site.WebUrl
                         GrantedTo=$who; Roles=($p.Roles -join ',') }
    }
  }
} | Sort-Object Roles -Descending
```

```
Site                Url                              GrantedTo                       Roles
------------------  -------------------------------  ------------------------------  -----
HR Handbook         /sites/hr-handbook               Everyone except external users  write   <-- ⚠⚠⚠
Policies            /sites/policies                  Everyone except external users  read    <-- ⚠⚠
```

⭐ **Row one is `write`, and that is a different finding from `read`.** Org-wide **read** is the
disclosure risk that a Copilot readiness review looks for. ⭐ **Org-wide *write* on a site that grounds
the assistant is the integrity risk from
[`../../60-ai-and-secure-ai/data-poisoning/`](../../60-ai-and-secure-ai/data-poisoning/) §2** — any
employee can author text Copilot will restate as company policy.

⚠ Graph's SharePoint permission surface varies by API version — ⭐ **verify in the tenant, and use the
SharePoint admin centre's sharing reports**, which are usually faster and more complete for link-level
data.

**③ Then the report only the admin centre gives you:**

```
SharePoint admin centre → Reports → Data access governance
   ⭐ "Sharing links" report          — every Anyone / org-wide link, per site
   ⭐ "Sites shared with Everyone…"   — the §2 finding, pre-computed
   "Content shared externally"
```

⭐ **Run these before writing a single script.** They compute exactly what §2 path ③ makes hard, and
almost nobody knows they exist.

---

## 4. Reducing the surface without stopping the business

**In order of value:**

| Control | ⭐ Effect |
|---|---|
| ⭐ **Anonymous link expiry** | bounds every future link — one field |
| ⭐ **Default link type = "People with existing access"** | ⭐ the default becomes safe; sharing still works |
| **Domain allow/block list** | external sharing only to known partners |
| ⭐ **Sensitivity labels on sites** | [`../microsoft-365-groups/`](../microsoft-365-groups/) §5 — one choice, several settings |
| **Block download on unmanaged devices** | via CA app-enforced restrictions |
| **Site access reviews** | for org-wide and external grants |

⭐ **Changing the default link type is the highest-leverage single setting in this topic.** Most
over-sharing is not malice or ignorance — **it is the default button.** Moving the default from
"People in your organisation" to "People with existing access" means the casual click grants nothing
new, and anyone who genuinely needs to widen access must choose to.

> ⭐ **Design the default, not the training.** You will not train 4,000 people out of clicking the
> highlighted button; you can change which button is highlighted.

---

## 5. ⭐ Retention, deletion and the second copy

**SharePoint keeps more than people expect, and that is both control and exposure:**

```
Delete a file  →  site Recycle Bin (93 days)  →  second-stage Recycle Bin
⭐ Version history  →  every prior version, ⭐ inheriting the CURRENT permissions
⭐ Retention label / policy  →  ⭐ preservation hold library — content survives deletion
```

⭐ **"We deleted it" is rarely true in SharePoint**, which is the point of retention and a genuine
problem for a data-subject deletion request. ⚠ **A retention policy set to *retain* overrides a user
deletion** — and content in the preservation hold library is discoverable by eDiscovery even though
it is invisible to the user.

⭐ **Version history is the subtler one**: restricting a document today does not restrict who could
read it yesterday, but **prior versions carry the file's current permissions** — so tightening
permissions does close old versions, while *sharing* a file exposes its whole history. **People assume
they are sharing "the latest version"; they are sharing the document's past.**

---

## 6. What breaks

**Auditing site membership only.** §2 — ⭐ links and unique permissions are invisible there.

**Anonymous links with no expiry.** §3 — ⭐ a 2021 link from a leaver still works.

**Default link type set wide.** §4 — ⭐ the default is the cause of most over-sharing.

**Org-wide *write*, not just read.** §3 — the integrity risk, not merely disclosure.

**Assuming "Everyone except external users" is a restriction.** ⭐ It is every account in the tenant —
the same finding as `Authenticated Users` in
[`../../00-foundations/linux-and-windows/`](../../00-foundations/linux-and-windows/) §4.

**Broken inheritance nobody tracks.** §2 path ④.

**Believing deletion is deletion.** §5 — recycle bins, versions, preservation hold.

**Sharing a file without considering version history.** §5.

**Not running the Data Access Governance reports.** §3 — ⭐ they already compute the hard part.

**Training instead of changing defaults.** §4.

---

## 7. Customer discovery questions

1. What is **`SharingCapability`**, and is there an ⭐ **anonymous link expiry**? *(§3.)*
2. What is the ⭐ **default link type**? *(§4 — the single highest-leverage setting.)*
3. Have you run the **Data Access Governance** reports? *(§3.)*
4. How many sites are shared with **"Everyone except external users"** — and how many with **write**?
5. Are **sensitivity labels** applied to sites?
6. Is external sharing **domain-restricted**?
7. Who reviews **broken inheritance** and item-level grants?
8. What is your answer to a **deletion request**, given version history and preservation hold? *(§5.)*
9. ⭐ Before Copilot: has anyone listed org-wide **write** grants? *(§3.)*

---

## 8. Remember it

**Hook — "Teams and OneDrive are SharePoint."** One store, many front doors.

**Analogy — a building where every employee can cut keys.** ⭐ Site membership is the staff list on
the wall — visible, reviewable, and **not how most people actually got in.** ⭐ **They got in because
somebody cut them a key and posted it** (a sharing link), and the "Anyone" key ⭐ **opens the door for
whoever is holding it, with no name, no badge check and no expiry.** Auditing the staff list tells you
almost nothing about who can open the door.

**The one thing:** ⭐ **change the default sharing link type to "People with existing access".** Most
over-sharing is not a decision — it is the highlighted button, clicked four thousand times a week by
people trying to do their jobs. **Training does not survive contact with a default;** moving the
default means the casual click grants nothing new and deliberate widening stays possible. It is one
setting, it changes behaviour immediately, and it is the cheapest large reduction in exposure
available in M365.

**Runner-up:** ⭐ **an "Anyone" link is a bearer secret standing in for an identity** — the same
failure as a storage shared key and an AI API key, in a third product.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. Where do Teams files and OneDrive actually live?
2. ⭐ Name the four access paths and say which two are invisible from site membership.
3. Rank the sharing link types by severity, and say what "Anyone" defeats.
4. ⭐ Which three products share the "bearer secret instead of identity" failure?
5. What does `AnonymousLinkExpirationInDays = 0` mean in practice?
6. What is the difference in kind between org-wide read and org-wide write?
7. ⭐ Which single setting reduces exposure most, and why does it beat training?
8. Which pre-built reports compute the hard part, and where are they?
9. Name three reasons "we deleted it" may be false.
10. Why does version history matter when sharing a file?

<details>
<summary>Answers</summary>

1. ⭐ **SharePoint Online** — Teams files are a document library; OneDrive is a SharePoint site per
   user.
2. **Site membership, direct site permissions, ⭐ sharing links, ⭐ item-level unique permissions.**
   ⭐ The last two are **invisible from site membership**.
3. ⭐ **"Anyone"** (anonymous) → "People in org" → "Specific people" → "People with existing access".
   ⭐ "Anyone" defeats **Conditional Access, MFA, device compliance and named attribution**.
4. ⭐ **SharePoint "Anyone" links, storage account shared keys, AI API keys.**
5. ⭐ **Anonymous links never expire** — one created years ago by a leaver still works.
6. Read is the ⭐ **disclosure** risk (Copilot readiness); ⭐ **write** is the **integrity** risk — any
   employee can author content the assistant restates as fact.
7. ⭐ **Default link type = "People with existing access".** ⭐ Because most over-sharing is the
   default button, and training does not survive contact with a default.
8. ⭐ **Data Access Governance** reports in the **SharePoint admin centre** — sharing links and sites
   shared with Everyone.
9. **Recycle bins (93 days + second stage), version history, and ⭐ the preservation hold library.**
10. ⭐ You share the document's **entire history**, not just the latest version — prior versions carry
    the file's current permissions.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §3 tenant settings check, the org-wide grant sweep, and the Data Access
  Governance reports. **Runnable today on the E5 licence — no Azure subscription needed.**
- **`break-fix/`** ⭐ — create an **"Anyone" link** to a test document, open it in a private window
  **with no sign-in at all**, then set an expiry and a safer default link type and show the difference.
  **Opening your own tenant's file while signed out is the single most persuasive demo in M365.**
- **`security/`** — sharing configuration record; anonymous link inventory with ages; org-wide read
  and ⭐ write grants; sites without sensitivity labels; broken-inheritance report.
- **`operations/`** — link expiry and review cadence; external sharing domain list with an owner;
  deletion-request procedure accounting for versions and preservation hold.
- **`architecture-decisions/`** — ADR: default link type is "People with existing access"; anonymous
  links expire; container labels mandatory — ⭐ with the "design the default, not the training"
  reasoning recorded.
- **`customer-use-cases/`** — §7 answered; the org-wide **write** finding presented separately from
  read, as a Copilot integrity risk.

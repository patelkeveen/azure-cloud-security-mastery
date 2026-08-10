# Day 3 — Collaboration Governance

> Standard set by [DAY-01](DAY-01.md). `✅ verified` / `⚠ check` convention applies.

**Outcome:** you can explain who can reach what across SharePoint, OneDrive, Teams and M365
Groups — and prove it. Collaboration governance is where **oversharing** is created, and
oversharing is the single largest real risk that Copilot exposes, because Copilot surfaces
whatever a user could already reach.

---

## 1. Connect

```powershell
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser   # ✅
Install-Module MicrosoftTeams -Scope CurrentUser                           # ✅

Connect-SPOService -Url https://<tenant>-admin.sharepoint.com              # ✅
Connect-MicrosoftTeams                                                     # ✅
Connect-MgGraph -Scopes 'Group.Read.All','Sites.Read.All','Directory.Read.All'
```

**Permission:** SharePoint Administrator / Teams Administrator, or Global Administrator.

**Behind the scenes:** an **M365 Group is the identity object**; the Team, the SharePoint site,
the mailbox and the planner are *attached* to it. Creating a Team creates a group, a site and a
mailbox. **Deleting the group deletes all of them.** This one fact explains most accidental data
loss in M365.

---

## 2. Tenant-level sharing posture — the setting with real blast radius

```powershell
Get-SPOTenant | Select-Object SharingCapability,DefaultSharingLinkType,
    DefaultLinkPermission,RequireAnonymousLinksExpireInDays,
    PreventExternalUsersFromResharing                                       # ✅
```

`SharingCapability` in increasing risk order:

| Value | Meaning |
|---|---|
| `Disabled` | Internal only |
| `ExistingExternalUserSharingOnly` | Only guests already in the directory |
| `ExternalUserSharingOnly` | New guests allowed; **must authenticate** |
| `ExternalUserAndGuestSharing` | **Anonymous "Anyone" links** — no authentication at all |

**`DefaultSharingLinkType` is the most consequential single setting in M365.** If it is
`AnonymousAccess`, every user clicking *Share* generates a link that works for anyone who has it,
forever, with no sign-in. If it is `Direct` ("specific people"), the default is safe and users
must opt into broader sharing.

> **Site-level cannot exceed tenant-level.** Tenant sharing is a ceiling, not a default. Tightening
> the tenant setting immediately constrains every site beneath it — which is powerful and is also
> how you break a live business at 2pm. Change it in a maintenance window, after measuring.

```powershell
Get-SPOSite -Limit All | Select-Object Url,SharingCapability,StorageUsageCurrent,LastContentModifiedDate |
    Sort-Object StorageUsageCurrent -Descending | Select-Object -First 20   # ✅
```

---

## 3. Find the oversharing — the deliverable that gets you hired

```powershell
# Sites sharing more permissively than you'd expect
Get-SPOSite -Limit All |
    Where-Object { $_.SharingCapability -eq 'ExternalUserAndGuestSharing' } |
    Select-Object Url,Owner,SharingCapability                               # ✅

# Guests in the directory, oldest first - the stale-access population
Get-MgUser -Filter "userType eq 'Guest'" -All -Property Id,DisplayName,Mail,CreatedDateTime,SignInActivity |
    Select-Object DisplayName,Mail,CreatedDateTime |
    Sort-Object CreatedDateTime | Select-Object -First 25                   # ⚠ check: SignInActivity needs AuditLog.Read.All and a premium licence
```

**Everyone / Everyone except external users** — search for any site granting these. They are the
canonical oversharing mechanism: an admin grants "Everyone except external users" once, and every
employee can now read a payroll folder. Copilot then cheerfully summarises it.

**The framing to use with a customer:** *"Copilot does not leak data. It reveals the permissions
you already had."* That reframes an AI conversation into a governance project, which is the honest
and more valuable engagement.

---

## 4. Teams and group lifecycle

```powershell
Get-Team | Format-Table DisplayName,Visibility,Archived                     # ✅
Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All -Property Id,DisplayName,Visibility,CreatedDateTime |
    Format-Table DisplayName,Visibility,CreatedDateTime                     # ✅
```

Three governance controls worth knowing cold:

- **Group creation restriction** — by default *any* user can create an M365 Group (and therefore a
  Team, a site, and a mailbox). Restricting creation to a security group is the first governance
  control most tenants need. ⚠ Configured via Entra group settings; verify current method.
- **Expiration policy** — groups auto-expire unless an owner renews. The only thing that stops
  unbounded sprawl. Requires P1.
- **Naming policy** — prefix/suffix and blocked words, so `Team Awesome` becomes
  `SALES-Team Awesome-EU`.

**Ownerless groups are the failure state.** When the only owner leaves, nobody can renew,
approve membership, or manage sharing — and the content becomes unmanaged but still accessible.
**Audit for zero-owner groups.**

```powershell
Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All |
  ForEach-Object {
    $o = Get-MgGroupOwner -GroupId $_.Id -ErrorAction SilentlyContinue
    if (-not $o) { [pscustomobject]@{ Group=$_.DisplayName; Owners=0 } }
  }                                                                          # ✅ pattern
```

---

## 5. Retention and the deletion question

Retention **labels** and **policies** in Purview decide how long content survives and whether a
user *can* delete it. The distinction customers always get wrong:

- **Retention** = you *cannot* delete it before the period ends (preservation)
- **Deletion** = it *must* go after the period (disposal)

A single policy can do both, and **retention wins over deletion** when policies conflict. In a
regulated vertical, that conflict resolution is an audit question — see
[Layer 7](../80-customer-scenarios/LAYER-7-INDUSTRY-VERTICALS.md).

---

## 6. Failure exercises

| Cause it | Expected |
|---|---|
| Set a site more permissive than the tenant ceiling | Setting refuses or silently clamps — verify which |
| Delete an M365 Group with a Team and site attached | Team, site and mailbox all go; observe the 30-day soft-delete window |
| Remove the last owner of a group | No error at removal; discover the failure later at renewal |
| Share externally with `SharingCapability = Disabled` | Sharing UI blocks; record the exact user-facing message |
| Apply a retention policy, then try to delete content | Deletion appears to succeed; item is preserved — explain where it went |

---

## 7. Teach-back

1. **What does creating a Team actually create?** An M365 Group plus a SharePoint site, mailbox,
   planner and Teams channel structure — all owned by the group.
2. **Why is `DefaultSharingLinkType` so important?** It decides whether the *default* action of
   every user is safe or anonymous.
3. **Can a site be more permissive than the tenant?** No. Tenant is a ceiling.
4. **Why do ownerless groups matter?** Nobody can renew, approve or govern them; content persists
   unmanaged.
5. **Retention vs deletion, and which wins?** Preservation vs disposal; retention wins.
6. **Why does Copilot make oversharing urgent?** It surfaces what permissions already allowed —
   it changes discoverability, not access.

---

## 8. Deliverables

| Facet | Artifact |
|---|---|
| `lab/` | Sharing posture report; guest inventory; ownerless-group list |
| `break-fix/` | The five failures with exact messages |
| `security/` | Oversharing findings; "Everyone except external" grants; anonymous-link exposure |
| `operations/` | Guest review SOP; group lifecycle policy; sharing-change runbook |
| `architecture-decisions/` | ADR: chosen sharing model and what it costs the business |
| `customer-use-cases/` | Education (huge guest population) vs finance (strict external controls) |

**Cleanup:** remove test guests, delete test Teams (and purge from soft-delete if testing that),
restore tenant sharing settings to their original values — **record them before you change them.**

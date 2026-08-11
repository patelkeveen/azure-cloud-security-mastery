# Day 4 — PIM, roles and least privilege

> **Theory first:** [`pim-and-access-reviews`](../30-identity-and-nhi/pim-and-access-reviews/) —
> the **2×2 matrix** (eligible/active × time-bound/permanent) ·
> [`service-principals`](../30-identity-and-nhi/service-principals/)
> **Time:** 8 hours.

---

## ⭐ The framing

**PIM does not change *who* can do what. It changes *for how long*.** The same people keep the
same capability; the exposure window collapses from permanent to hours. That distinction is the
answer to *"won't PIM slow us down?"* and it is the whole business case.

---

## Lab 4.1 — Measure standing privilege *(1 h)*

⭐ **Capture the "before". The trial expires and this number is the proof of the change.**

```powershell
Connect-MgGraph -Scopes 'RoleManagement.ReadWrite.Directory','Directory.Read.All','User.Read.All'

# Every ACTIVE directory role assignment — standing privilege, today
Get-MgDirectoryRole -All | ForEach-Object {
  $r = $_
  Get-MgDirectoryRoleMember -DirectoryRoleId $r.Id -All -EA SilentlyContinue | ForEach-Object {
    [pscustomobject]@{
      Role    = $r.DisplayName
      Member  = $_.AdditionalProperties.userPrincipalName ?? $_.AdditionalProperties.displayName
      Type    = ($_.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.','')
    }
  }
} | Sort-Object Role | Format-Table -AutoSize
```

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet security -Name 'standing-privilege-before' `
  -Note 'Baseline standing role assignments before PIM rollout — the number this sprint reduces' `
  -Command { Get-MgDirectoryRole -All | ForEach-Object { $r=$_
               Get-MgDirectoryRoleMember -DirectoryRoleId $r.Id -All -EA SilentlyContinue |
                 ForEach-Object { [pscustomobject]@{ Role=$r.DisplayName
                   Member=$_.AdditionalProperties.userPrincipalName } } } }
```

---

## Lab 4.2 — The 2×2, built deliberately *(2 h)*

|  | **Time-bound** | **Permanent** |
|---|---|---|
| **Eligible** | ⭐ the target state | acceptable for rare roles |
| **Active** | temporary elevation | ⚠ standing privilege — what you are removing |

- [ ] Make a seeded user **eligible** for User Administrator
- [ ] Configure role settings: **max duration, MFA on activation, justification, approval**
- [ ] Assign a second user as **approver**
- [ ] ⭐ Leave break-glass as **permanent active** — deliberately, and be able to say why

> ⭐ **Break-glass must not be PIM-eligible.** Activation can itself fail — and that failure is
> precisely the scenario break-glass exists for. Being asked *"why isn't break-glass in PIM?"* in
> an interview and answering this is a differentiator.

---

## Lab 4.3 — Activate, with approval *(1.5 h)*

- [ ] As the eligible user, request activation with justification
- [ ] As the approver, approve it
- [ ] Confirm the role works **only after** activation
- [ ] Wait for expiry — confirm it **deactivates automatically**

```powershell
# The audit trail — who elevated, when, why, who approved
Get-MgAuditLogDirectoryAudit -Filter "category eq 'RoleManagement'" -Top 50 |
  Select-Object ActivityDateTime, ActivityDisplayName,
    @{n='Actor';e={$_.InitiatedBy.User.UserPrincipalName}},
    @{n='Target';e={($_.TargetResources.DisplayName) -join ','}} |
  Format-Table -AutoSize
```

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet lab -Name 'pim-activation-with-approval' `
  -Note 'End-to-end PIM activation: request, justification, approval, automatic expiry' `
  -Command { Get-MgAuditLogDirectoryAudit -Filter "category eq 'RoleManagement'" -Top 20 |
             Select-Object ActivityDateTime, ActivityDisplayName,
               @{n='Actor';e={$_.InitiatedBy.User.UserPrincipalName}} }
```

---

## Lab 4.4 — PIM for Groups, and role-assignable groups *(1.5 h)*

- [ ] Create a **role-assignable** group (`isAssignableToRole = true`)
- [ ] Assign a directory role to the **group**
- [ ] Bring the group under PIM — membership becomes activatable
- [ ] ⭐ Note: role-assignable groups **cannot be dynamic**

> ⭐ **Group ownership becomes privileged access.** The owner of a role-assignable group can
> effectively grant that role — which is the same self-elevation shape as User Access
> Administrator in Azure ([`azure-rbac`](../20-azure-platform/azure-rbac/) §3). **Fourth
> appearance of that pattern in this repo.**

---

## ⭐ Deliberate failure — two of them

**① Activation without MFA**

- [ ] Configure the role to require MFA on activation
- [ ] Attempt activation as a user with **no MFA registered**
- [ ] Record the verbatim failure

> ⭐ This is why [`okta-and-third-party-idp`](../35-active-directory-and-hybrid-identity/okta-and-third-party-idp/)
> matters: **CA custom controls never satisfied the MFA claim**, so PIM activation failed for
> third-party MFA users. ⚠ Custom controls **retire 30 Sep 2026** → External Authentication
> Methods.

**② Approval never granted**

- [ ] Request activation on an approval-required role
- [ ] Do not approve it
- [ ] ⭐ Observe the request **expire**, and that the user had no access throughout

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet break-fix -Name 'pim-activation-failures' `
  -Note 'Two failure modes: activation blocked by missing MFA, and an approval request expiring unapproved' `
  -Command { Get-MgAuditLogDirectoryAudit -Filter "category eq 'RoleManagement'" -Top 30 |
             Select-Object ActivityDateTime, ActivityDisplayName, Result, ResultReason }
```

---

## Lab 4.5 — Service principals are the ones that never leave *(1 h)*

```powershell
# Credentials and their expiry — the NHI half of least privilege
Get-MgApplication -All | ForEach-Object {
  $a = $_
  foreach ($c in @($a.PasswordCredentials) + @($a.KeyCredentials)) {
    [pscustomobject]@{
      App     = $a.DisplayName
      Kind    = if ($c.Hint) { 'secret' } else { 'certificate' }
      Expires = $c.EndDateTime
      DaysLeft= [int](([datetime]$c.EndDateTime) - (Get-Date)).TotalDays
    }
  }
} | Sort-Object DaysLeft | Format-Table -AutoSize
```

- [ ] Identify any app with a **secret** rather than a certificate or federated credential
- [ ] ⭐ Note that access reviews must cover **service principals**, not only users

---

## Close out

```powershell
cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 4: PIM, role-assignable groups, activation failures" ; git push
```

**Done when:**

- [ ] Standing-privilege **before** baseline captured
- [ ] Eligible assignment with MFA, justification and approval configured
- [ ] Full activation cycle observed, including automatic expiry
- [ ] Role-assignable group under PIM; ⭐ ownership-as-privilege understood
- [ ] Two activation failures recorded verbatim
- [ ] Service principal credential inventory captured

> **Tomorrow:** [`DAY-5.md`](DAY-5.md) — governance: access reviews, entitlement management,
> lifecycle. ⚠ **Start Day 5's access review early — it needs time to run.**

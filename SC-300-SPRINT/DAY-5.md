# Day 5 — Governance: access reviews, entitlement management, lifecycle

> **Theory first:** [`entitlement-management`](../30-identity-and-nhi/entitlement-management/) ·
> [`lifecycle-workflows`](../30-identity-and-nhi/lifecycle-workflows/) ·
> [`pim-and-access-reviews`](../30-identity-and-nhi/pim-and-access-reviews/)
> **Time:** 8 hours. ⚠ **Start Lab 5.1 first — reviews need time to run.**

---

## ⭐ The framing

Days 1–4 controlled **who gets in**. Today controls **who keeps getting in** — and that is where
real estates fail. Access is granted correctly and then never removed, which is the accumulation
problem behind every over-permission finding in this repo.

---

## Lab 5.1 — ⭐ Start the access review FIRST *(30 min, then it runs)*

```powershell
Connect-MgGraph -Scopes 'AccessReview.ReadWrite.All','EntitlementManagement.ReadWrite.All',
                        'Group.ReadWrite.All','User.Read.All','Directory.ReadWrite.All'

$group = Get-MgGroup -Filter "displayName eq 'Dept-Engineering'"

New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter @{
  displayName = 'SC300 - Engineering membership review'
  scope = @{
    '@odata.type' = '#microsoft.graph.accessReviewQueryScope'
    query = "/groups/$($group.Id)/transitiveMembers"
    queryType = 'MicrosoftGraph'
  }
  reviewers = @(@{ query = './manager'; queryType = 'MicrosoftGraph' })   # ⭐ manager as reviewer
  settings = @{
    mailNotificationsEnabled = $true
    reminderNotificationsEnabled = $true
    justificationRequiredOnApproval = $true
    defaultDecisionEnabled = $true
    defaultDecision = 'Deny'                      # ⭐ no response = removed
    instanceDurationInDays = 3
    autoApplyDecisionsEnabled = $true             # ⭐ decisions actually take effect
    recurrence = @{
      pattern = @{ type = 'weekly'; interval = 1 }
      range   = @{ type = 'noEnd'; startDate = (Get-Date).ToString('yyyy-MM-dd') }
    }
  }
}
```

⭐ **Three settings do all the work, and defaults get them wrong:**

| Setting | ⭐ Why |
|---|---|
| `defaultDecision = 'Deny'` | ⭐ **no response removes access.** The opposite default preserves everything forever |
| `autoApplyDecisionsEnabled = true` | otherwise decisions are ⭐ **opinions, not changes** |
| `reviewers = ./manager` | the only person who knows if it is still needed |

> ⭐ **A review that defaults to Approve and does not auto-apply is theatre**: it produces a
> compliance artifact and changes nothing. Ask to see both settings before believing any access
> review programme.

---

## Lab 5.2 — Entitlement management *(2.5 h)*

Build a **catalog → access package → policy** so access becomes requestable rather than granted.

- [ ] Create a catalog; add the Engineering group, a SharePoint site, an app
- [ ] Create an access package bundling them
- [ ] Policy: **who may request**, approver, ⭐ **expiry**, justification required
- [ ] Request it as a seeded user; approve it; confirm all resources arrive together

```powershell
New-MgEntitlementManagementAccessPackage -BodyParameter @{
  displayName = 'Engineering Onboarding'
  description = 'Group + site + app, granted together, expiring together'
  catalog     = @{ id = $catalogId }
}
```

> ⭐ **The point is the bundle.** Granting a group, a site and an app separately means they are
> revoked separately — which is to say, incompletely. An access package makes joining and leaving
> a single event with a single expiry.

- [ ] ⭐ Add an **external** requestor policy — this is how guests get governed access instead of
  ad-hoc invitations ([`external-identities`](../30-identity-and-nhi/external-identities/))

---

## Lab 5.3 — Lifecycle workflows *(2 h)*

⚠ **Lifecycle Workflows requires the Entra ID Governance SKU, not P2.** ⭐ **Check first and
record the result** — if it is unavailable, that itself is a licensing finding worth capturing,
and it is exactly the §1 gate from
[`licensing-and-service-limits`](../40-microsoft-365-platform/licensing-and-service-limits/).

```powershell
Get-MgSubscribedSku | ForEach-Object { $_.ServicePlans } |
  Where-Object ServicePlanName -match 'IDENTITY_GOVERNANCE|Entra_Identity_Governance' |
  Select-Object ServicePlanName, ProvisioningStatus
```

**If available:**

- [ ] Joiner workflow: on hire date → add to groups, send TAP, notify manager
- [ ] ⭐ Leaver workflow: on `employeeLeaveDateTime` → disable, remove groups, revoke sessions
- [ ] Trigger the leaver workflow against the seeded offboarding user
- [ ] ⭐ Confirm **sessions were revoked**, not just the account disabled

> ⭐ **Disabling an account does not end existing sessions, and does not revoke sharing links
> that account created** ([`onedrive`](../40-microsoft-365-platform/onedrive/) §3). A leaver
> workflow that only disables is incomplete, and this is where you prove it.

---

## ⭐ Deliberate failure — the review that changes nothing

- [ ] Create a second review with `defaultDecision = 'Approve'` and `autoApplyDecisionsEnabled = false`
- [ ] Let it complete with **no reviewer response**
- [ ] ⭐ Confirm **everyone kept access** and a completed-review artifact exists
- [ ] Compare against Lab 5.1's review, where non-response removed access

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet break-fix -Name 'access-review-theatre' `
  -Note 'Two reviews, identical scope: one removes access on non-response, one preserves it and produces the same compliance artifact' `
  -Command { Get-MgIdentityGovernanceAccessReviewDefinition |
             Select-Object DisplayName, Status,
               @{n='DefaultDecision';e={$_.Settings.DefaultDecision}},
               @{n='AutoApply';e={$_.Settings.AutoApplyDecisionsEnabled}} }
```

> ⭐ **Both produce a green dashboard. Only one is a control.** This is the same
> *deployed-is-not-enforced* pattern as report-only CA, audit-mode policy and DMARC `p=none` —
> and it is now the sixth product in which this repo has found it.

---

## Close out

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/entitlement-management `
  -Facet lab -Name 'access-package-lifecycle' `
  -Note 'Bundle granted and expired as one event, including an external requestor policy' `
  -Command { Get-MgEntitlementManagementAccessPackage |
             Select-Object DisplayName, Description, CreatedDateTime }

cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 5: access reviews, entitlement management, lifecycle" ; git push
```

**Done when:**

- [ ] Access review running with ⭐ **Deny default + auto-apply**
- [ ] Access package requested, approved, resources arrived together
- [ ] External requestor policy exists
- [ ] Lifecycle workflow tested, **or** its licensing gap recorded as a finding
- [ ] ⭐ The "review that changes nothing" captured as a break-fix artifact

> **Tomorrow:** [`DAY-6.md`](DAY-6.md) — apps, consent and workload identity.

# Day 1 — Baseline, break-glass, telemetry on, seed the org

> **Theory first:** [`entra-users-and-groups`](../30-identity-and-nhi/entra-users-and-groups/) ·
> [`pim-and-access-reviews`](../30-identity-and-nhi/pim-and-access-reviews/) §break-glass
> **Time:** 3–4 hours. ⭐ **Deliberately short — most of today's value accrues while you sleep.**

---

## ⭐ Why today is not "the easy day"

Everything you enable today spends the next six days accumulating data. Everything you *don't*
enable today produces nothing by Day 7. **This is the highest-leverage day of the sprint and it
finishes early.**

---

## Lab 1.1 — Verify what actually landed *(20 min, read-only)*

```powershell
cd C:\IT\azure-cloud-security-mastery\SC-300-SPRINT
Connect-MgGraph -Scopes 'Organization.Read.All','Directory.Read.All','User.Read.All','Policy.Read.All'

.\Day0-Verify-Tenant.ps1 -OutFile .\evidence\day0-licence-state.json
```

**Confirm before continuing:**

- [ ] `SPE_E5` present (**not** `ENTERPRISEPREMIUM*` alone — that is Office 365 E5, no Entra P2)
- [ ] `AAD_PREMIUM_P2` status = `Success` (⚠ if `PendingProvisioning`, wait an hour)
- [ ] Your account is **licensed**

> ⭐ **Why the assignment check matters:** a licence in the tenant does nothing until assigned.
> [`licensing-and-service-limits`](../40-microsoft-365-platform/licensing-and-service-limits/) §1 —
> capability is gated by SKU and **the gate is silent**.

---

## Lab 1.2 — Break-glass, before any policy exists *(30 min)*

```powershell
.\Day1-New-BreakGlass.ps1            # dry run — read the plan
.\Day1-New-BreakGlass.ps1 -Apply     # ⭐ store the passwords offline BEFORE closing the window
```

**Then, manually — the script deliberately does not do these:**

- [ ] Exclude both from **every** CA policy (there are none yet; keep it that way as you add them)
- [ ] ⭐ Do **not** make them PIM-eligible — PIM activation is exactly what may be broken
- [ ] Do not license them
- [ ] **Test one now**, in a private window, and record the date

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet security -Name 'break-glass-design' `
  -Note 'Two cloud-only permanent GA accounts exist, excluded from all CA, tested working' `
  -Command { Get-MgUser -Filter "startswith(userPrincipalName,'breakglass')" |
             Select-Object UserPrincipalName, DisplayName, AccountEnabled }
```

> ⭐ **In a trial tenant, assume Microsoft support cannot recover you from a lockout.** One CA
> policy scoped to All users, with grant controls defaulting to **AND**, ends the sprint.

---

## Lab 1.3 — ⭐ Enable everything that learns *(45 min)*

```powershell
Connect-ExchangeOnline
.\Day1-Enable-Telemetry.ps1          # dry run
.\Day1-Enable-Telemetry.ps1 -Apply
```

The script refuses to run without break-glass. **That gate is deliberate.**

**Then the portal steps it reports** — each only starts learning when you click it:

| | Where | Why today |
|---|---|---|
| [ ] Defender for Endpoint: onboard this laptop, **ASR to Audit** | security.microsoft.com | days of device telemetry |
| [ ] Defender for Cloud Apps: M365 connector | security.microsoft.com/cloudapps | usage baseline |
| [ ] Insider Risk: enable + ⭐ **pseudonymisation on** | purview.microsoft.com | activity history |
| [ ] Attack simulation: launch one campaign | security.microsoft.com/attacksimulator | campaigns take days |
| [ ] Confirm `MailItemsAccessed` in the audit set | EXO | ⭐ forward-only capture |

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/identity-protection `
  -Facet operations -Name 'telemetry-enabled' `
  -Note 'Day 1 enablement so risk detections have six days of signal by Day 7' `
  -Command { Get-MgIdentityConditionalAccessPolicy | Select-Object DisplayName, State }
```

---

## Lab 1.4 — Seed the org *(30 min)*

```powershell
..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1
..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply
```

Creates 16 users with a manager chain, 4 dynamic groups, an offboarding-test user, an app
registration.

> ⭐ **A pristine tenant generates no signal.** Dynamic groups need attributes to match on,
> access reviews need a manager chain, PIM needs someone to elevate, lifecycle workflows need a
> leaver. **Create the mess before you practise cleaning it.**

**Verify the dynamic rule actually evaluated — membership is not instant:**

```powershell
Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" |
  ForEach-Object {
    [pscustomobject]@{
      Group   = $_.DisplayName
      Rule    = $_.MembershipRule
      State   = $_.MembershipRuleProcessingState
      Members = @(Get-MgGroupMember -GroupId $_.Id -All).Count
    }
  } | Format-Table -AutoSize
```

---

## ⭐ Deliberate failure — the part that transfers

**Break the dynamic membership rule and read the error.**

```powershell
# Set a rule with a syntax error on purpose
$g = Get-MgGroup -Filter "displayName eq 'Dept-Engineering'"
Update-MgGroup -GroupId $g.Id -MembershipRule '(user.department -eq "Engineering"'   # ⭐ unclosed bracket
```

- [ ] Record the **verbatim** error
- [ ] Fix it, and note **how long** membership took to re-evaluate

> ⭐ That lag is the answer to *"I added the attribute, why isn't the user in the group?"* — the
> most common dynamic-group ticket, and it is not a bug.

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/entra-users-and-groups `
  -Facet break-fix -Name 'dynamic-rule-syntax-failure' `
  -Note 'Verbatim error for a malformed membership rule + measured re-evaluation lag' `
  -Command { Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" |
             Select-Object DisplayName, MembershipRule, MembershipRuleProcessingState }
```

---

## Close out

```powershell
cd ..
.\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 1: baseline, break-glass, telemetry, seeded org"
git push
```

**Done when:**

- [ ] Licence state captured as JSON
- [ ] Two break-glass accounts, tested, excluded, passwords stored offline
- [ ] ⭐ Identity Protection, MDE/ASR audit, MDCA, Insider Risk, audit log **all on and learning**
- [ ] Seeded org with dynamic groups evaluating
- [ ] One deliberate failure recorded verbatim
- [ ] Committed

> **Tomorrow:** [`DAY-2.md`](DAY-2.md) — authentication methods and passwordless.
> ⚠ **Do not skip today's enablement to "get to the interesting part".** Day 7 depends on it.

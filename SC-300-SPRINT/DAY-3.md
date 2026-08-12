# Day 3 — Conditional Access

> **Theory first:** [`conditional-access`](../30-identity-and-nhi/conditional-access/) — read the
> **8-step evaluation order** and **grant controls default to AND** before touching anything.
> **Time:** 8 hours. ⭐ **The core day of SC-300.**

---

## ⚠ Gate — do not start without this

```powershell
# Break-glass must work TODAY, not "last week"
# Sign in as breakglass1 in a private window. Right now. Then continue.
```

- [ ] Break-glass sign-in succeeded **today**
- [ ] Both accounts excluded from every existing policy

> ⭐ **Today you will deliberately lock yourself out.** That is the lab. It is only safe because
> of the gate above.

---

## Lab 3.1 — Build the policy set in report-only *(2.5 h)*

⭐ **Every policy starts in `enabledForReportingButNotEnforced`.** This is the "watch first"
pattern (`RETENTION.md` §3b) and today is where you earn the habit.

Build these, all report-only, all excluding break-glass:

| # | Policy | Grant |
|---|---|---|
| 1 | Block legacy authentication | Block |
| 2 | Require MFA for all users | ⭐ authentication strength from Day 2 |
| 3 | Require MFA for admins | phishing-resistant strength |
| 4 | Require compliant device for M365 | ⚠ compliantDevice — see the AND trap below |
| 5 | Block from unapproved countries | Block |
| 6 | Session: sign-in frequency for admins | Session control |

```powershell
Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess','Policy.Read.All','Directory.Read.All'

$bg = @(Get-MgUser -Filter "startswith(userPrincipalName,'breakglass')").Id

New-MgIdentityConditionalAccessPolicy -BodyParameter @{
  displayName = 'CA01 - Block legacy authentication'
  state       = 'enabledForReportingButNotEnforced'      # ⭐ always start here
  conditions  = @{
    users        = @{ includeUsers = @('All'); excludeUsers = $bg }
    applications = @{ includeApplications = @('All') }
    clientAppTypes = @('exchangeActiveSync','other')      # ⭐ this IS legacy auth
  }
  grantControls = @{ operator = 'OR'; builtInControls = @('block') }
}
```

---

## Lab 3.2 — ⭐ What-If, before enabling anything *(1 h)*

**What-If is the CA equivalent of `what-if` in Bicep and `plan` in Terraform** — the dry run that
tells you what a policy *would* do.

- [ ] Run What-If for: a normal user, an admin, a guest, ⭐ **a break-glass account**
- [ ] Confirm break-glass is **excluded from everything**
- [ ] Record which policies apply to each persona

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/conditional-access `
  -Facet security -Name 'whatif-persona-matrix' `
  -Note 'Which policies apply to which persona, including proof break-glass is excluded from all' `
  -Command { Get-MgIdentityConditionalAccessPolicy |
             Select-Object DisplayName, State,
               @{n='Grants';e={$_.GrantControls.BuiltInControls -join ','}},
               @{n='Op';e={$_.GrantControls.Operator}},
               @{n='ExcludedUsers';e={@($_.Conditions.Users.ExcludeUsers).Count}} }
```

---

## Lab 3.3 — ⭐ The AND trap, deliberately *(1 h)*

**This is the single most valuable exercise in the sprint.**

```powershell
# One policy. Two grant controls. Operator AND (the DEFAULT).
New-MgIdentityConditionalAccessPolicy -BodyParameter @{
  displayName = 'CA-TRAP - MFA AND compliant device'
  state       = 'enabled'                                  # ⭐ deliberately enabled
  conditions  = @{
    users        = @{ includeUsers = @('All'); excludeUsers = $bg }
    applications = @{ includeApplications = @('All') }
  }
  grantControls = @{
    operator        = 'AND'                                # ⭐ THE DEFAULT. This is the trap.
    builtInControls = @('mfa','compliantDevice')
  }
}
```

- [ ] Sign in as a **seeded user** on a **non-compliant device**
- [ ] ⭐ **You are now locked out.** Record the verbatim error and the sign-in log failure reason
- [ ] Recover with **break-glass**
- [ ] Change `operator` to `OR` and repeat — observe the difference
- [ ] Delete the trap policy

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/conditional-access `
  -Facet break-fix -Name 'grant-controls-default-to-and' `
  -Note 'Deliberate lockout: two grant controls with the default AND operator on a tenant with no compliant devices. Recovered via break-glass.' `
  -Command { Get-MgAuditLogSignIn -Top 10 -Filter "status/errorCode ne 0" |
             Select-Object CreatedDateTime, UserPrincipalName,
               @{n='Error';e={$_.Status.ErrorCode}},
               @{n='Reason';e={$_.Status.FailureReason}},
               @{n='CA';e={($_.AppliedConditionalAccessPolicies |
                             Where-Object Result -eq 'failure').DisplayName -join ','}} }
```

> ⭐ **This is why break-glass exists, and you have now proved it rather than read it.** In a
> customer tenant this is a P1 incident; here it is a Tuesday afternoon and an artifact.

---

## Lab 3.4 — Token lifetime, the invisible cause *(1 h)*

⭐ **Role and group targeting is evaluated only at token issuance.** Removing someone from a
group does **not** end their session.

- [ ] Sign in as a seeded user, obtain a session
- [ ] Remove them from the group a policy targets
- [ ] ⭐ **Access still works.** Measure how long until it stops
- [ ] Revoke sessions explicitly and observe the immediate change

```powershell
Revoke-MgUserSignInSession -UserId <userId>
```

> ⭐ **This is the most common false diagnosis in identity**: *"the policy isn't working."* It is
> working; the token predates it. Compare `iat` in the token
> ([`data-formats-and-apis`](../00-foundations/data-formats-and-apis/) §3) against the change
> time. **One claim settles an argument that otherwise takes a meeting.**

---

## Lab 3.5 — ⭐ The objectives neither plan covered *(1.5 h)*

✅ **Verified against the SC-300 study guide 2026-08-12.** These are named exam objectives under
*Implement authentication and access management* — the **largest domain** — and they were missing
from both seven-day plans. ⭐ **Now that you have Azure, all of them are runnable.**

**① Authentication context + protected actions**

```powershell
# Authentication context — CA that applies to an ACTION, not just an app
Get-MgIdentityConditionalAccessAuthenticationContextClassReference |
  Select-Object Id, DisplayName, IsAvailable
```

- [ ] Create an authentication context (e.g. `c1` — "High risk operations")
- [ ] ⭐ Bind it to a **protected action** — deleting a CA policy, or changing authentication methods
- [ ] Attempt that action and observe the step-up prompt

> ⭐ **Protected actions are how you stop a compromised admin session deleting your CA policies.**
> Standing privilege is one problem; a *live* privileged session is another, and this is the
> control for the second.

**② Continuous access evaluation (CAE)**

- [ ] Confirm CAE is active for a test user
- [ ] Sign in, then **revoke sessions** and watch access drop in near real time
- [ ] ⭐ Compare against the Lab 3.4 token-lifetime lag — **that contrast is the point of CAE**

**③ Global Secure Access** — ⭐ an exam objective in both plans' blind spot

- [ ] Enable Global Secure Access in the tenant
- [ ] Deploy the client to this machine
- [ ] Configure **Microsoft 365 traffic forwarding**
- [ ] ⭐ Apply a CA policy to the GSA-derived network location — identity-aware network access

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/conditional-access `
  -Facet lab -Name 'auth-context-protected-actions-cae-gsa' `
  -Note 'Exam objectives missing from both sprint plans: authentication context bound to a protected action, CAE revocation timing vs token lifetime, and Global Secure Access traffic forwarding' `
  -Command { Get-MgIdentityConditionalAccessAuthenticationContextClassReference |
             Select-Object Id, DisplayName, IsAvailable }
```

---

## Lab 3.6 — Move to enforce *(1 h)*

- [ ] Review report-only impact in sign-in logs
- [ ] Promote policies 1–3 to `enabled`
- [ ] Re-test every persona
- [ ] ⭐ Re-verify break-glass **after** enforcing

---

## Close out

```powershell
cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 3: Conditional Access, AND-trap lockout and recovery" ; git push
```

**Done when:**

- [ ] Six policies built, report-only first, break-glass excluded from all
- [ ] What-If persona matrix captured
- [ ] ⭐ **Deliberate lockout performed and recovered** — verbatim error recorded
- [ ] Token-lifetime lag measured
- [ ] Policies 1–3 enforcing, break-glass re-verified

> **Tomorrow:** [`DAY-4.md`](DAY-4.md) — PIM and least privilege.

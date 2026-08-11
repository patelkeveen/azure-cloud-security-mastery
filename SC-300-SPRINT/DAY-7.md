# Day 7 — External identities, Identity Protection, and proving it all

> **Theory first:** [`external-identities`](../30-identity-and-nhi/external-identities/) ·
> [`identity-protection`](../30-identity-and-nhi/identity-protection/)
> **Time:** 8 hours. ⭐ **Today only works because Day 1 enabled the telemetry.**

---

## ⭐ The payoff

Six days ago you turned Identity Protection on in report-only and it looked like nothing
happened. **Today it has six days of sign-in history to reason about.** That is the data-latency
principle returning its investment, and it is the argument to make to any customer starting a
security programme: **enable the telemetry on day one of the engagement, not on the day you need
it.**

---

## Lab 7.1 — Identity Protection, with real data *(2 h)*

```powershell
Connect-MgGraph -Scopes 'IdentityRiskyUser.Read.All','IdentityRiskEvent.Read.All',
                        'AuditLog.Read.All','Policy.Read.All','User.Read.All'

# ① What has six days of signal produced?
Get-MgRiskDetection -All |
  Select-Object DetectedDateTime, RiskEventType, RiskLevel, RiskState,
                UserPrincipalName, IPAddress,
                @{n='Location';e={ "$($_.Location.City), $($_.Location.CountryOrRegion)" }} |
  Sort-Object DetectedDateTime -Descending | Format-Table -AutoSize

# ② Risky users
Get-MgRiskyUser -All |
  Select-Object UserPrincipalName, RiskLevel, RiskState, RiskLastUpdatedDateTime |
  Sort-Object RiskLastUpdatedDateTime -Descending
```

**Generate some yourself if the tenant is quiet:**

- [ ] Sign in from a VPN endpoint in another country → **atypical travel / unfamiliar location**
- [ ] Sign in via Tor if available → **anonymous IP address**
- [ ] Attempt several failed sign-ins → **password spray** patterns

⭐ **Then the distinction people get wrong:**

| | Answers | Persists? |
|---|---|---|
| **Sign-in risk** | *is this session suspicious?* | no — per session |
| ⭐ **User risk** | *is this account likely compromised?* | ⭐ **yes, until remediated** |

- [ ] Remediate a risky user (password reset) and confirm risk state → `remediated`
- [ ] Dismiss a false positive and note the difference

---

## Lab 7.2 — Move risk policies to enforce *(1 h)*

```powershell
# Review what report-only WOULD have done before enforcing — the same discipline as Day 3
Get-MgAuditLogSignIn -Top 200 |
  Where-Object { $_.RiskLevelDuringSignIn -in 'medium','high' } |
  Select-Object CreatedDateTime, UserPrincipalName, RiskLevelDuringSignIn,
    @{n='ReportOnly';e={($_.AppliedConditionalAccessPolicies |
        Where-Object Result -match 'reportOnly').DisplayName -join ','}}
```

- [ ] Promote the sign-in risk policy to `enabled`
- [ ] Promote the user risk policy to `enabled`
- [ ] ⭐ **Re-verify break-glass immediately afterwards**

---

## Lab 7.3 — External identities *(2 h)*

- [ ] Invite a guest via **entitlement management** (Day 5's external requestor policy), not ad hoc
- [ ] Configure **cross-tenant access settings**: inbound/outbound trust, ⭐ **trust MFA claims
  from the partner tenant**
- [ ] Set the **guest user role to restricted** — not member-equivalent
- [ ] Run an access review scoped to guests

```powershell
# ⭐ Guests who have never signed in — the finding an access review exists to catch
Get-MgUser -All -Filter "userType eq 'Guest'" -Property UserPrincipalName,CreatedDateTime,SignInActivity |
  Select-Object UserPrincipalName,
    @{n='AgeDays';e={[int]((Get-Date) - [datetime]$_.CreatedDateTime).TotalDays}},
    @{n='LastSignIn';e={ $_.SignInActivity.LastSignInDateTime ?? 'never' }} |
  Sort-Object AgeDays -Descending
```

> ⭐ **Trusting the partner's MFA claim is the setting that makes B2B usable.** Without it guests
> are re-prompted for MFA they have already satisfied in their home tenant, so people route around
> the process with a personal account — **the governed-path argument again, fifth appearance.**

---

## Lab 7.4 — ⭐ The evidence sweep *(2 h)*

**This is the day's most important lab, and it is not technical.**

```powershell
cd C:\IT\azure-cloud-security-mastery
.\tools\Build-CoverageRegister.ps1
```

- [ ] For every topic touched this week, check facet coverage
- [ ] Fill gaps — a topic at 2/6 needs **one more artifact** to become **WRITTEN**
- [ ] Write the `architecture-decisions` ADRs: break-glass design, PIM mandatory, consent workflow,
      federated credentials over secrets
- [ ] Answer the `customer-use-cases` discovery questions from each topic README against **your own
      tenant** — you are now a customer with a real estate

```powershell
# What is the honest score for the week?
Select-String -Path COVERAGE.md -Pattern '^\| \*\*WRITTEN\*\*' | ForEach-Object { $_.Line }
```

> ⭐ **The number of WRITTEN topics is the week's real result** — not how many labs were "done".
> It has been **0/144 for licensing reasons**; anything above zero is a first.

---

## Lab 7.5 — ⭐ Rehearse the expiry *(1 h)*

**The lab nobody gets to run, and a genuine customer scenario.**

- [ ] Record the current PIM state: eligible assignments, time-bound active assignments
- [ ] ⭐ Note precisely what will happen on **2026-09-10**:

```
eligible assignments        → ⭐ DELETED
time-bound ACTIVE           → ⭐ converted to PERMANENT   (privilege INCREASES)
CA policies with P2 risk    → ⭐ stop evaluating
```

```powershell
.\SC-300-SPRINT\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
  -Facet operations -Name 'pim-licence-expiry-plan' `
  -Note 'State before licence lapse on 2026-09-10, and the predicted effect: eligible deleted, time-bound active made permanent, risk policies stop evaluating' `
  -Command { Get-MgDirectoryRole -All | ForEach-Object { $r=$_
               Get-MgDirectoryRoleMember -DirectoryRoleId $r.Id -All -EA SilentlyContinue |
                 ForEach-Object { [pscustomobject]@{ Role=$r.DisplayName
                   Member=$_.AdditionalProperties.userPrincipalName } } } }
```

> ⭐ **A licence lapse that *increases* standing privilege is a security event dressed as a billing
> event.** Being the person in the room who knows this is worth more than the certification.

⚠ **Set the cancellation reminder for 2026-09-05.**

---

## Close out — the week

```powershell
.\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 7: identity protection with real data, external identities, evidence sweep" ; git push
```

**Done when:**

- [ ] Risk detections reviewed from ⭐ **six days of real signal**
- [ ] Sign-in risk vs user risk distinguished by behaviour, not definition
- [ ] Risk policies enforcing; break-glass re-verified
- [ ] Guests governed through entitlement management; cross-tenant trust configured
- [ ] ⭐ **Evidence swept; WRITTEN count recorded**
- [ ] Expiry rehearsal captured; cancellation reminder set

---

## ⭐ What you can now say that you could not on 10 August

Not *"I studied SC-300"*. This:

- *"I locked myself out with the default AND operator on grant controls, and recovered with
  break-glass."*
- *"I can tell you in ten seconds whether a token is delegated or app-only, and what that means for
  blast radius."*
- *"I have run an access review that removed access and one that changed nothing, and I can show
  you the two settings that make the difference."*
- *"I removed the last secret from a pipeline and proved the federated credential fails when the
  branch changes."*
- *"I know what happens to PIM when the licence lapses, because I planned for it."*

⭐ **Every one of those is a story with an artifact behind it.** That is what the week bought, and
it survives the trial expiring.

> **Next:** SC-200 (Days 8–20 of the trial) — Defender XDR, KQL hunting, incident response.
> ⭐ **The telemetry you enabled on Day 1 will have two weeks of depth by then.**

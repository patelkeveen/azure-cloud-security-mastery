# Day 2 — Authentication methods, passwordless, SSPR

> **Theory:** [`authentication-methods`](../30-identity-and-nhi/authentication-methods/) ·
> [`passwordless-and-passkeys`](../30-identity-and-nhi/passwordless-and-passkeys/)
> **Official labs:** `Lab_08` MFA · `Lab_09` SSPR · `Lab_12` Smart lockout · `Lab_15` MFA reg policy
> **Time:** 8 hours. ⭐ **Highest-weight exam domain (25–30%) — Days 2 and 3 carry the marks.**

---

## ⭐ The framing

**Authentication strength is a policy *input*, not a user setting.** Everything today exists so that
tomorrow's Conditional Access has something meaningful to require.

> ⭐ **A CA policy demanding phishing-resistant MFA is worthless if nobody has registered a method
> that satisfies it.** Capability and adoption are different facts, and the gap between them is what
> breaks CA rollouts.

**Preflight:**

```powershell
cd C:\IT\azure-cloud-security-mastery\SC-300-SPRINT
.\Invoke-SprintCheck.ps1 -Day 2      # must be all PASS before starting

Connect-MgGraph -Scopes 'Policy.ReadWrite.AuthenticationMethod','Policy.Read.All',
  'UserAuthenticationMethod.ReadWrite.All','Reports.Read.All','User.ReadWrite.All',
  'Directory.Read.All','Group.ReadWrite.All'
```

---

## Lab 2.1 — Measure before you change *(45 min)*

⭐ **Capture the "before". The trial expires and this is your proof of change.**

```powershell
# ① What is enabled tenant-wide, and targeted at whom?
$p = Get-MgPolicyAuthenticationMethodPolicy
$p.AuthenticationMethodConfigurations | ForEach-Object {
    [pscustomobject]@{
        Method  = $_.Id
        State   = $_.State
        Targets = ($_.AdditionalProperties.includeTargets | ForEach-Object { $_.id }) -join ','
    }
} | Sort-Object State, Method | Format-Table -AutoSize
```

```powershell
# ② ⭐ What have users actually REGISTERED? This is the gap that breaks rollouts.
$reg = Get-MgReportAuthenticationMethodUserRegistrationDetail -All

$reg | Select-Object UserPrincipalName, IsAdmin, IsMfaRegistered, IsMfaCapable,
        IsPasswordlessCapable, IsSsprRegistered, IsSsprEnabled,
        @{n='Methods';e={ $_.MethodsRegistered -join ',' }} |
  Sort-Object IsMfaRegistered | Format-Table -AutoSize

"MFA registered : {0}/{1}" -f @($reg | Where-Object IsMfaRegistered).Count, @($reg).Count
"Passwordless   : {0}/{1}" -f @($reg | Where-Object IsPasswordlessCapable).Count, @($reg).Count
"⭐ ADMINS without MFA:"
$reg | Where-Object { $_.IsAdmin -and -not $_.IsMfaRegistered } | Select-Object UserPrincipalName
```

⭐ **An admin without MFA is the single most sellable finding in an assessment.** It takes one query
and it lands in any customer conversation.

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/authentication-methods `
  -Facet security -Name 'auth-registration-baseline' `
  -Note 'Day 2 BEFORE state: method policy, registration coverage, and admins without MFA' `
  -Command { Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
             Select-Object UserPrincipalName, IsAdmin, IsMfaRegistered, IsPasswordlessCapable }
```

---

## Lab 2.2 — ⭐ Temporary Access Pass — the bootstrap *(1 h)*

⚠ **No official Microsoft lab covers TAP**, and it is a named exam objective.

> ⭐ **TAP solves the chicken-and-egg problem of passwordless:** you cannot register a passkey
> without signing in, and you cannot sign in without a credential. TAP is a time-limited passcode
> that gets a user to the registration page once. **Being able to name it as the answer is
> interview-grade.**

```powershell
# Enable the method
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
  -AuthenticationMethodConfigurationId 'TemporaryAccessPass' `
  -BodyParameter @{
      '@odata.type'          = '#microsoft.graph.temporaryAccessPassAuthenticationMethodConfiguration'
      state                  = 'enabled'
      defaultLifetimeInMinutes = 60
      defaultLength            = 8
      isUsableOnce             = $false      # ⭐ multi-use for onboarding; single-use is stricter
      minimumLifetimeInMinutes = 10
      maximumLifetimeInMinutes = 480
  }
```

```powershell
# Issue one to a seeded user
$u = Get-MgUser -Filter "startswith(userPrincipalName,'aphillips')" | Select-Object -First 1
$tap = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $u.Id -BodyParameter @{
    lifetimeInMinutes = 60
    isUsableOnce      = $false
}
"TAP for $($u.UserPrincipalName): $($tap.TemporaryAccessPass)  (expires $($tap.LifetimeInMinutes) min)"
```

- [ ] Sign in as that user **in a private window** using the TAP
- [ ] Register a **passkey** or the Authenticator app during that session
- [ ] ⭐ Confirm the TAP is consumed / expires and cannot be reused after its lifetime

---

## Lab 2.3 — The method ladder *(1.5 h)*

**Configure strongest-first, so weak methods become the documented exception.**

| Order | Method | Config note |
|---|---|---|
| 1 | ⭐ **Passkey (FIDO2)** | phishing-resistant — the target state |
| 2 | Windows Hello for Business | phishing-resistant |
| 3 | Authenticator — ⭐ **push + number matching + context** | show app name and location |
| 4 | TAP | Lab 2.2 |
| 5 | ⚠ SMS / voice | leave enabled for the §2.6 failure drill, then restrict |

```powershell
# Authenticator with number matching and context ON (these are the anti-fatigue controls)
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
  -AuthenticationMethodConfigurationId 'MicrosoftAuthenticator' `
  -BodyParameter @{
      '@odata.type' = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethodConfiguration'
      state         = 'enabled'
      featureSettings = @{
          numberMatchingRequiredState      = @{ state='enabled'; includeTarget=@{ id='all_users'; targetType='group' } }
          displayAppInformationRequiredState = @{ state='enabled'; includeTarget=@{ id='all_users'; targetType='group' } }
          displayLocationInformationRequiredState = @{ state='enabled'; includeTarget=@{ id='all_users'; targetType='group' } }
      }
  }
```

```powershell
# Passkey / FIDO2
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
  -AuthenticationMethodConfigurationId 'Fido2' `
  -BodyParameter @{
      '@odata.type'                    = '#microsoft.graph.fido2AuthenticationMethodConfiguration'
      state                            = 'enabled'
      isAttestationEnforced             = $false   # ⚠ true requires attested keys only
      isSelfServiceRegistrationAllowed  = $true
  }
```

> ⭐ **Number matching exists because push-fatigue attacks worked.** The user must type a number
> shown on the sign-in screen, so approving blindly is no longer possible. **Know why the control
> exists, not just where the toggle is** — that is the difference in an interview.

⚠ **Dates to know:** passkeys become the default experience around **1 Sep 2026**, and
Microsoft-provided **SMS/voice is retired 1 Feb 2027**. ⚠ Re-verify both before quoting to a
customer.

---

## Lab 2.4 — Authentication strengths *(1 h)*

⭐ **This is how "require MFA" becomes "require *this kind* of MFA" — the difference between a
control and a gesture.**

```powershell
Get-MgPolicyAuthenticationStrengthPolicy |
  Select-Object DisplayName, PolicyType, RequirementsSatisfied,
    @{n='Combinations';e={ $_.AllowedCombinations -join '; ' }} | Format-Table -AutoSize -Wrap
```

```powershell
# ⭐ Custom strength: phishing-resistant only. Attach it to a CA policy tomorrow.
New-MgPolicyAuthenticationStrengthPolicy -BodyParameter @{
    displayName        = 'SC300 - Phishing resistant only'
    description        = 'FIDO2/passkey, WHfB, or certificate-based auth. Nothing phishable.'
    allowedCombinations = @('fido2','windowsHelloForBusiness','x509CertificateMultiFactor')
}
```

- [ ] Note which **built-in** strength maps to which combinations
- [ ] ⭐ Understand why `password + sms` is **not** in your custom strength

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/passwordless-and-passkeys `
  -Facet lab -Name 'phishing-resistant-strength' `
  -Note 'Custom authentication strength allowing only phishing-resistant combinations, for Day 3 CA' `
  -Command { Get-MgPolicyAuthenticationStrengthPolicy |
             Select-Object DisplayName, PolicyType,
               @{n='Combinations';e={$_.AllowedCombinations -join '; '}} }
```

---

## Lab 2.5 — SSPR, registration campaign, password protection *(2 h)*

**Official labs: `Lab_09` (SSPR), `Lab_15` (registration policy), `Lab_12` (smart lockout).**

- [ ] Run `Lab_09` — SSPR enabled for a group, methods required, registration enforced
- [ ] ⭐ **Test SSPR as a seeded user, not as yourself**
- [ ] Run `Lab_15` — registration campaign nudging Authenticator over SMS
- [ ] Run `Lab_12` — smart lockout thresholds and custom banned passwords

> ⭐ **Testing as an admin proves nothing.** Your account has different methods, different policies
> and different roles — the "works on my machine" undeclared variable from
> [`troubleshooting-method`](../00-foundations/troubleshooting-method/) §3, in identity form.

```powershell
# Custom banned passwords - add your org's obvious ones
Update-MgBetaDirectorySetting -DirectorySettingId <id> -Values @(
    @{ Name='BannedPasswordList'; Value='contoso;kwin;hyderabad;summer2026' }
    @{ Name='EnableBannedPasswordCheck'; Value='true' }
    @{ Name='LockoutThreshold'; Value='10' }
    @{ Name='LockoutDurationInSeconds'; Value='60' }
)
```

⚠ Verify the current cmdlet/module — the password-protection settings surface has moved between
beta and v1.0.

---

## ⭐ Lab 2.6 — Deliberate failure: legacy authentication *(1 h)*

**Legacy protocols cannot do MFA. That is the whole reason they are the top attack vector — not a
bug, a protocol limitation.**

```powershell
# ① Is anything using it? Check BEFORE you block.
Get-MgAuditLogSignIn -Top 200 -Filter "createdDateTime ge $((Get-Date).AddDays(-7).ToString('yyyy-MM-dd'))" |
  Where-Object { $_.ClientAppUsed -in 'IMAP4','POP3','SMTP AUTH','MAPI Over HTTP','Other clients','Exchange ActiveSync' } |
  Group-Object ClientAppUsed | Select-Object Count, Name
```

- [ ] Attempt an IMAP or SMTP AUTH sign-in as a seeded user
- [ ] Record the **verbatim** failure
- [ ] ⭐ **Note that MFA was never prompted.** The protocol has no mechanism to carry it.

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/authentication-methods `
  -Facet break-fix -Name 'legacy-auth-cannot-mfa' `
  -Note 'Legacy protocol sign-in fails without ever prompting MFA - why blocking legacy auth is a PREREQUISITE to any MFA policy, not an optional hardening step' `
  -Command { Get-MgAuditLogSignIn -Top 50 |
             Where-Object { $_.ClientAppUsed -notin 'Browser','Mobile Apps and Desktop clients' } |
             Select-Object CreatedDateTime, UserPrincipalName, ClientAppUsed,
               @{n='Error';e={$_.Status.ErrorCode}} }
```

> ⭐ **The exam and the job both want the same sentence:** *"Block legacy authentication first,
> because a protocol that cannot carry an MFA challenge silently bypasses every MFA policy you
> write."*

---

## Close out

```powershell
# AFTER state - the pair to Lab 2.1
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/authentication-methods `
  -Facet operations -Name 'auth-method-ladder-after' `
  -Note 'Day 2 AFTER state: method ladder configured, TAP enabled, phishing-resistant strength created' `
  -Command { (Get-MgPolicyAuthenticationMethodPolicy).AuthenticationMethodConfigurations |
             Select-Object Id, State }

cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 2: authentication methods, TAP, passwordless, SSPR" ; git push
.\SC-300-SPRINT\Invoke-SprintCheck.ps1 -Day 3
```

**Done when:**

- [ ] Registration **gap** measured, not assumed — including ⭐ admins without MFA
- [ ] TAP enabled and **used** to register a passkey
- [ ] Authenticator number matching + context ON
- [ ] Custom phishing-resistant strength created — ⭐ Day 3 will attach it
- [ ] SSPR tested **as a seeded user**
- [ ] Official labs 08, 09, 12, 15 complete
- [ ] ⭐ Legacy auth failure captured verbatim
- [ ] 3 evidence artifacts filed → `authentication-methods` should now be ⭐ **WRITTEN**

> **Tomorrow:** [`DAY-3.md`](DAY-3.md) — Conditional Access, including a deliberate lockout.
> ⚠ **Verify break-glass works before you start Day 3.** Do it tonight, not tomorrow morning.

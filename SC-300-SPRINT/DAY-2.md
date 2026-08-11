# Day 2 — Authentication methods, passwordless, SSPR

> **Theory first:** [`authentication-methods`](../30-identity-and-nhi/authentication-methods/) ·
> [`passwordless-and-passkeys`](../30-identity-and-nhi/passwordless-and-passkeys/)
> **Time:** 6–8 hours.

---

## ⭐ The framing for today

**Authentication strength is a *policy input*, not a user setting.** Today you build the methods
so that Day 3's Conditional Access has something meaningful to require — a CA policy demanding
phishing-resistant MFA is worthless if nobody has registered a method that satisfies it.

⚠ **Two live dates from the repo, both inside your horizon:**
**1 Sep 2026** passkeys become default · **1 Feb 2027** Microsoft-provided SMS/voice retired.

---

## Lab 2.1 — Inventory before you change anything *(45 min)*

```powershell
Connect-MgGraph -Scopes 'Policy.ReadWrite.AuthenticationMethod','UserAuthenticationMethod.Read.All',
                        'Reports.Read.All','User.Read.All','Directory.Read.All'

# ① What is enabled tenant-wide, and for whom?
$p = Get-MgPolicyAuthenticationMethodPolicy
$p.AuthenticationMethodConfigurations |
  Select-Object Id, State,
    @{n='Targets';e={ ($_.AdditionalProperties.includeTargets | ForEach-Object { $_.id }) -join ',' }} |
  Sort-Object State, Id | Format-Table -AutoSize
```

```powershell
# ② ⭐ What have users actually REGISTERED? Capability != adoption.
Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
  Select-Object UserPrincipalName, IsMfaRegistered, IsPasswordlessCapable,
                IsSsprRegistered, @{n='Methods';e={ $_.MethodsRegistered -join ',' }} |
  Format-Table -AutoSize
```

> ⭐ **This is the gap that breaks CA rollouts.** Enabling a method and users registering it are
> different facts, and a policy requiring the method blocks everyone who has not.

---

## Lab 2.2 — Build the method ladder *(1.5 h)*

Configure in **this order**, strongest first, so the weak ones become the exception:

| Order | Method | Note |
|---|---|---|
| 1 | ⭐ **Passkey (FIDO2)** | phishing-resistant — the target state |
| 2 | Windows Hello for Business | phishing-resistant |
| 3 | Microsoft Authenticator — **push + number matching** | ⭐ display context on |
| 4 | Temporary Access Pass | ⭐ **the onboarding path to passwordless** |
| 5 | ⚠ SMS / voice | leave for the failure lab, then restrict |

```powershell
# Enable TAP — the bootstrap that makes passwordless rollout possible at all
Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration `
  -AuthenticationMethodConfigurationId 'TemporaryAccessPass' `
  -BodyParameter @{ '@odata.type' = '#microsoft.graph.temporaryAccessPassAuthenticationMethodConfiguration'
                    state = 'enabled' }
```

> ⭐ **Temporary Access Pass is the answer to the chicken-and-egg problem**: you cannot register a
> passkey without signing in, and you cannot sign in without a credential. Being able to name TAP
> as the resolution is an interview-grade answer.

---

## Lab 2.3 — Authentication strengths *(1 h)*

```powershell
Get-MgPolicyAuthenticationStrengthPolicy |
  Select-Object DisplayName, PolicyType, @{n='Combos';e={ $_.AllowedCombinations -join '; ' }} |
  Format-Table -AutoSize -Wrap
```

- [ ] Create a **custom strength** allowing only phishing-resistant combinations
- [ ] Note which built-in strength maps to which combinations

⭐ **Tomorrow you will attach this to a CA policy.** Authentication strength is how "require MFA"
becomes "require *this kind* of MFA" — the difference between a control and a gesture.

---

## Lab 2.4 — Registration campaign and SSPR *(1 h)*

- [ ] Enable **registration campaign** nudging Authenticator over SMS
- [ ] Configure **SSPR**: methods required, registration enforced
- [ ] ⭐ Test SSPR end-to-end **as a seeded user, not as yourself**

> ⭐ **Testing as an admin proves nothing** — your account has different methods, different
> policies and different roles. It is the "it works on my machine" undeclared variable from
> [`troubleshooting-method`](../00-foundations/troubleshooting-method/) §3, in identity form.

---

## ⭐ Deliberate failure — legacy authentication

**Legacy auth protocols cannot do MFA. That is the entire reason they are the top attack vector.**

```powershell
# ① Is anything still using it? (before you block)
Get-MgAuditLogSignIn -Filter "clientAppUsed eq 'IMAP4' or clientAppUsed eq 'POP3' or clientAppUsed eq 'SMTP AUTH'" -Top 50 |
  Select-Object CreatedDateTime, UserPrincipalName, ClientAppUsed, @{n='Status';e={$_.Status.ErrorCode}}
```

- [ ] Attempt an IMAP/SMTP AUTH sign-in with a seeded user
- [ ] Record the **verbatim** failure
- [ ] ⭐ Note that MFA was **never prompted** — the protocol has no mechanism for it

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/authentication-methods `
  -Facet break-fix -Name 'legacy-auth-cannot-mfa' `
  -Note 'Legacy protocol sign-in fails without ever prompting MFA — why blocking legacy auth is prerequisite to any MFA policy' `
  -Command { Get-MgAuditLogSignIn -Filter "clientAppUsed eq 'IMAP4'" -Top 20 |
             Select-Object CreatedDateTime, UserPrincipalName, ClientAppUsed }
```

---

## Close out

```powershell
.\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/authentication-methods `
  -Facet security -Name 'auth-method-registration-gap' `
  -Note 'Registration state per user — the gap that breaks a CA rollout' `
  -Command { Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
             Select-Object UserPrincipalName, IsMfaRegistered, IsPasswordlessCapable }

cd .. ; .\tools\Build-CoverageRegister.ps1
git add . ; git commit -m "SC-300 sprint Day 2: authentication methods, passwordless, SSPR" ; git push
```

**Done when:**

- [ ] Method policy exported; ⭐ registration **gap** measured, not assumed
- [ ] TAP enabled and used to register a passkey
- [ ] Custom phishing-resistant authentication strength created
- [ ] SSPR tested **as a seeded user**
- [ ] Legacy auth failure captured verbatim

> **Tomorrow:** [`DAY-3.md`](DAY-3.md) — Conditional Access, including a deliberate lockout.
> ⚠ **Confirm your break-glass works before you start Day 3.**

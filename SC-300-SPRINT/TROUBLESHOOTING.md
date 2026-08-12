# Troubleshooting — every failure you will hit, and the fix

> ⭐ **This file exists so you never have to ask anyone.** Find the error text, apply the fix.
> If something is not here, the method is in
> [`../00-foundations/troubleshooting-method/`](../00-foundations/troubleshooting-method/):
> pick the test that eliminates the most, and reproduce the failure, not the success.

---

## 1. Graph connection

| Symptom | Cause | Fix |
|---|---|---|
| `Connect-MgGraph` hangs / no browser | non-interactive shell | `Connect-MgGraph -Scopes <...> -UseDeviceAuthentication` |
| Script runs but a later call 403s | ⭐ **existing session has narrower scopes** | `Disconnect-MgGraph` then reconnect with the full scope list |
| `Get-MgContext` empty after connect | consent not completed | re-run, complete the browser prompt |

**Check what you actually hold, always:**

```powershell
(Get-MgContext).Scopes -join ', '
```

⭐ **`if (-not (Get-MgContext))` reuses whatever session exists.** A narrower one silently wins.
Check the scopes, not the presence of a context.

---

## 2. ⭐ `Authorization_RequestDenied` (403) — the one that matters

> **This error is IDENTICAL whether the token lacks the SCOPE or you lack the ROLE.** Effective
> rights on a delegated token are the **intersection** of the two. Diagnose both.

```powershell
# ① Scope half
$need = 'RoleManagement.ReadWrite.Directory'
if ($need -notin (Get-MgContext).Scopes) { "MISSING SCOPE: $need" }

# ② Role half — are you actually a Global Admin, permanently?
$ga = Get-MgDirectoryRole -Filter "roleTemplateId eq '62e90394-69f5-4237-9190-012177145e10'"
Get-MgDirectoryRoleMember -DirectoryRoleId $ga.Id -All |
  ForEach-Object { $_.AdditionalProperties.userPrincipalName }
```

⭐ **If you hold Global Admin as a PIM-eligible assignment, you must ACTIVATE it first.** Eligible
is not active, and the token carries only what is active. Then **reconnect** — the old token does
not gain the role.

**Fix:** `.\Repair-BreakGlassRole.ps1 -Apply`

---

## 3. Licensing

| Symptom | Cause | Fix |
|---|---|---|
| Feature missing though "we have E5" | ⭐ **licence not assigned to the user** | assign it — see below |
| `Set-MgUserLicense` fails | ⭐ **`UsageLocation` not set** | set it **first** |
| Plan shows `PendingProvisioning` | trial still provisioning | wait an hour, re-run Day0 |
| Policy applies to some users only | ⭐ mixed licences | check every targeted user is licensed |

```powershell
Update-MgUser -UserId <upn> -UsageLocation CA           # ⭐ FIRST. Assignment fails without it.
$sku = (Get-MgSubscribedSku | Where-Object SkuPartNumber -eq 'SPE_E5').SkuId
Set-MgUserLicense -UserId <upn> -AddLicenses @{SkuId=$sku} -RemoveLicenses @()
```

⚠ **Do not license the break-glass accounts.** They need no mailbox and no Intune.

---

## 4. Exchange Online

| Symptom | Fix |
|---|---|
| `Get-AdminAuditLogConfig` not recognised | `Install-Module ExchangeOnlineManagement` then `Connect-ExchangeOnline` |
| `Connect-ExchangeOnline` hangs | add `-Device` |
| Cmdlet works in portal, not PowerShell | you hold the role via PIM — **activate, then reconnect** |

---

## 5. ⭐ Locked out of your own tenant

**This will happen on Day 3. It is the lab.**

```
1. Private/incognito window
2. Sign in as breakglass1@KWin.onmicrosoft.com  (password: %USERPROFILE%\.breakglass)
3. entra.microsoft.com → Protection → Conditional Access
4. Set the offending policy to Report-only or Off
5. Sign out. Sign back in as yourself.
```

⭐ **If break-glass also fails, you have no recovery path in a trial tenant.** That is why
`Day1-Enable-Telemetry.ps1` refuses to run until break-glass exists and is excluded — and why you
test it *before* writing policies, not after.

**Prevention, every time:**

```powershell
# Every enabled policy must exclude both break-glass accounts
$bg = @(Get-MgUser -Filter "startswith(userPrincipalName,'breakglass')").Id
Get-MgIdentityConditionalAccessPolicy -All | Where-Object State -ne 'disabled' | ForEach-Object {
  $missing = @($bg | Where-Object { $_ -notin $_.Conditions.Users.ExcludeUsers })
  if ($missing) { "NOT EXCLUDED: $($_.DisplayName)" }
}
```

---

## 6. Conditional Access behaving unexpectedly

| Symptom | Cause |
|---|---|
| Policy "not working" after a group change | ⭐ **the token predates the change** — role/group targeting is evaluated at **token issuance** |
| Everyone blocked by one policy | ⭐ **grant controls default to AND**, not OR |
| Policy has no effect at all | state is `enabledForReportingButNotEnforced` |
| MAM/BYOD users blocked | you required **compliant device**; use **approved client app** instead |

```powershell
Revoke-MgUserSignInSession -UserId <userId>    # forces a new token
```

⭐ **Check `iat` in the token before believing a policy is broken:**

```powershell
function Read-Jwt { param($t)
  $p=$t.Split('.')[1].Replace('-','+').Replace('_','/'); while($p.Length%4){$p+='='}
  [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))|ConvertFrom-Json }
```

---

## 7. Groups and identities

| Symptom | Cause | Fix |
|---|---|---|
| Dynamic group empty after adding attribute | ⭐ **re-evaluation lag** — normal | wait; check `MembershipRuleProcessingState` |
| Rule rejected | syntax | quotes and brackets — `(user.department -eq "Engineering")` |
| Role-assignable group won't take a dynamic rule | ⭐ **by design** — cannot be both | use assigned membership |

---

## 8. Azure

| Symptom | Cause | Fix |
|---|---|---|
| Day0 says "No Azure subscription" | CLI session stale | `az login` then `az account list --refresh -o table` |
| `az account list` shows only `N/A(tenant level account)` | ⭐ **that is a placeholder, not a subscription** | check the portal; the free account may still be provisioning |
| Sentinel/Key Vault labs unavailable | no subscription | as above |

⭐ **Spend control before any Azure lab.** Set a budget alert, and delete resources the same day
unless tomorrow needs them. Labs 07 and 10 are the only expensive ones.

---

## 9. Repo hygiene

| Symptom | Fix |
|---|---|
| CI fails: `COVERAGE.md is STALE` | `.\tools\Build-CoverageRegister.ps1` then commit it |
| `CRLF will be replaced by LF` warnings | ⭐ **expected** — `.gitattributes` normalises. Ignore |
| Broken relative link in CI | run the sweep in §10 |
| Evidence not counting toward WRITTEN | needs ≥3 of 6 facets filled for that topic |

---

## 10. Self-check — run this any time

```powershell
cd C:\IT\azure-cloud-security-mastery

# ① Register current?
.\tools\Build-CoverageRegister.ps1 -Check

# ② All relative links resolve?
$bad=@(); Get-ChildItem -Recurse -File -Filter *.md |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object { $d=$_
    foreach($m in [regex]::Matches((Get-Content $d.FullName -Raw),'\[[^\]]*\]\(([^)#:]+\.(?:md|ps1))\)')){
      if(-not(Test-Path (Join-Path $d.DirectoryName $m.Groups[1].Value))){ $bad+="$($d.Name) -> $($m.Groups[1].Value)" }}}
"broken links: $($bad.Count)"; $bad

# ③ Scripts parse?
Get-ChildItem SC-300-SPRINT -Filter *.ps1 | ForEach-Object { $e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e)
  if($e){"FAIL $($_.Name)"}else{"OK   $($_.Name)"} }
```

---

## 11. ⭐ The general method, when nothing above fits

1. **State the observation precisely.** Not "it's broken" — what exactly differs from expected?
2. **Form a falsifiable hypothesis.**
3. ⭐ **Pick the test that eliminates the most**, not the one nearest the symptom.
4. **Record the result, including the boring ones.** An eliminated hypothesis is progress.
5. ⭐ **Reproduce the failure before claiming a fix.** Passing in the environment that never failed
   is not evidence.

⭐ **The invisible-cause list**, when everything visible checks out: **token lifetime**, **DNS/TTL
caching**, **clock skew**, **line endings**, **encoding/BOM**, **trailing whitespace**,
**homoglyphs**.

⭐ In this sprint, **token lifetime is the cause far more often than anything else.**

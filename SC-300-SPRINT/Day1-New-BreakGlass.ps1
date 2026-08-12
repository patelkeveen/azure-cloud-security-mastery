<#
.SYNOPSIS
    Create two break-glass Global Administrators - BEFORE the first Conditional Access policy.

.DESCRIPTION
    ⭐ Order matters and it is not negotiable.

    A Conditional Access policy scoped to "All users" includes you. Grant controls default to
    AND (30-identity-and-nhi/conditional-access), so one policy requiring a compliant device on
    a tenant with no compliant devices locks every human out - including the person who wrote it.

    In a production tenant Microsoft support can recover you. ⭐ In a trial tenant, assume they
    cannot and that you have lost 30 days of work.

    The design pattern, and it is worth being able to recite in an interview:
      * CLOUD-ONLY  - not synced, so an on-prem outage or AD compromise cannot affect them
      * Excluded from EVERY Conditional Access policy, without exception
      * Permanent Global Administrator - NOT PIM-eligible (PIM activation can itself fail)
      * Long random passphrase, stored offline, split between two people in the real world
      * Alerted on: any sign-in by these accounts is an incident until proven otherwise
      * Reviewed and tested on a schedule, because an untested break-glass is a hope

    DRY RUN BY DEFAULT. Idempotent.

.PARAMETER Apply
    Actually create the accounts.

.PARAMETER Prefix
    UPN prefix. Default 'breakglass'. Produces breakglass1@ and breakglass2@<initial domain>.

.EXAMPLE
    .\Day1-New-BreakGlass.ps1
    .\Day1-New-BreakGlass.ps1 -Apply

.NOTES
    ⭐ Passwords are NEVER printed. They are written to a single locked-down file outside the
    repository (see -CredentialPath). Move them to a password manager and delete the file.
    If you lose them, delete the accounts and re-run - that is cheaper than a weak recovery path.

    ⚠ Run this yourself, in your own shell. Do not have an automation or an agent run it on your
    behalf: a break-glass credential that has passed through a third party can no longer be said
    to be in sole custody, which is the only property that makes it worth having.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Apply,
    [string]$Prefix = 'breakglass',

    # ⭐ Credentials are written to a FILE, never to stdout.
    #
    # Why: stdout ends up in shell history, terminal scrollback, CI logs, screen shares and -
    #      increasingly - AI agent transcripts. A break-glass credential's entire value is
    #      PROVABLE SOLE CUSTODY: you must be able to say exactly who has held it. Anything that
    #      broadcasts it destroys that property at the moment of creation.
    #
    # ⚠ Default is deliberately OUTSIDE the repository so it cannot be committed by accident.
    [string]$CredentialPath = (Join-Path $env:USERPROFILE '.breakglass')
)

$ErrorActionPreference = 'Stop'

$Scopes = @(
    'User.ReadWrite.All'
    'RoleManagement.ReadWrite.Directory'
    'Directory.ReadWrite.All'
    'Policy.Read.All'
)

# ⭐ Check the SCOPES, not merely that a context exists.
#
# The original bug: `if (-not (Get-MgContext))` reuses whatever session already exists. A
# context established earlier with narrower scopes silently wins, the role assignment then
# fails 403 Authorization_RequestDenied, and nothing obvious says why.
#
# ⭐ And Authorization_RequestDenied looks IDENTICAL whether the token lacks the SCOPE or the
#    caller lacks the ROLE. Effective rights on a delegated token are the INTERSECTION of the
#    two. Telling them apart is the skill - see 30-identity-and-nhi/oauth-oidc-saml-and-api-auth.
$ctx = Get-MgContext
$missing = @()
if ($ctx) { $missing = @($Scopes | Where-Object { $_ -notin $ctx.Scopes }) }

if (-not $ctx -or $missing.Count) {
    if ($ctx) {
        Write-Host "  [WARN] Existing Graph session is missing required scope(s):" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "         $_" -ForegroundColor Yellow }
        Write-Host "         Reconnecting with the full set - a narrower session would fail 403 later." -ForegroundColor DarkGray
    }
    Connect-MgGraph -Scopes $Scopes -NoWelcome
    $ctx = Get-MgContext
}
if (-not $ctx) { throw "Not connected to Graph." }

$stillMissing = @($Scopes | Where-Object { $_ -notin $ctx.Scopes })
if ($stillMissing.Count) {
    throw "Consent was not granted for: $($stillMissing -join ', '). Role assignment would fail 403."
}

$domain = (Get-MgOrganization).VerifiedDomains | Where-Object IsInitial | Select-Object -Expand Name
Write-Host ""
Write-Host "Domain : $domain" -ForegroundColor Green
Write-Host "Mode   : $(if($Apply){'APPLY'}else{'DRY RUN - pass -Apply'})" -ForegroundColor $(if($Apply){'Green'}else{'Yellow'})
Write-Host ""

function New-Passphrase {
    # Long and random beats short and clever. 40 chars from a wide alphabet.
    $chars = ([char[]](33..126)) -ne '"' -ne "'" -ne '`' -ne '\'
    -join (1..40 | ForEach-Object { $chars | Get-Random })
}

# Global Administrator role - activate the directory role if it has never been used.
$gaTemplate = '62e90394-69f5-4237-9190-012177145e10'
$gaRole = Get-MgDirectoryRole -Filter "roleTemplateId eq '$gaTemplate'" -ErrorAction SilentlyContinue
if (-not $gaRole -and $Apply) {
    $gaRole = New-MgDirectoryRole -RoleTemplateId $gaTemplate
}

$created = @()

foreach ($n in 1..2) {
    $upn = "$Prefix$n@$domain"
    $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Host "  [OK    ] Exists: $upn" -ForegroundColor Green
        $created += [pscustomobject]@{ Upn = $upn; Id = $existing.Id; Password = '(unchanged)' }
        continue
    }

    if (-not $Apply) {
        Write-Host "  [DRYRUN] Create $upn, assign permanent Global Administrator" -ForegroundColor Yellow
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($upn, 'Create break-glass Global Administrator')) { continue }

    $pw = New-Passphrase
    try {
        $u = New-MgUser -BodyParameter @{
            accountEnabled    = $true
            displayName       = "Break Glass $n (EMERGENCY - DO NOT USE)"
            mailNickname      = "$Prefix$n"
            userPrincipalName = $upn
            passwordProfile   = @{
                password                      = $pw
                forceChangePasswordNextSignIn = $false   # ⭐ deliberate: a forced change can itself block emergency access
            }
        }
        # ⭐ -ErrorAction Stop is load-bearing. Without it this cmdlet writes a NON-TERMINATING
        #    error: the catch never fires, execution continues, and the success line below
        #    prints over a role assignment that did not happen. That is exactly the
        #    "deployed is not enforced" failure this repo keeps finding - here in our own tool,
        #    reporting a security control that does not exist. See 00-foundations/cli-and-scripting sec.5.
        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $gaRole.Id -ErrorAction Stop `
            -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.Id)" }

        # ⭐ POST-CONDITION: never trust the call, read the state back.
        #    A control is not deployed because an API returned 2xx; it is deployed because you
        #    can see it. This is the same discipline as requiring RequestDisallowedByPolicy
        #    rather than "policy assigned" in 20-azure-platform/deployment-strategies sec.4.
        Start-Sleep -Seconds 2
        $isGa = @(Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All -ErrorAction SilentlyContinue |
                  Where-Object Id -eq $u.Id).Count -gt 0

        if (-not $isGa) {
            throw "User created, but Global Administrator assignment could NOT be verified. The account exists WITHOUT the role."
        }

        Write-Host "  [OK    ] Created $upn - Global Administrator VERIFIED" -ForegroundColor Green
        $created += [pscustomobject]@{ Upn = $upn; Id = $u.Id; Password = $pw }
    }
    catch {
        Write-Host "  [FAIL  ] $upn -> $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "           ⚠ If the user was created, it exists WITHOUT the role. Fix or delete it." -ForegroundColor Red
        if ($u -and $u.Id) {
            $created += [pscustomobject]@{ Upn = $upn; Id = $u.Id; Password = $pw; RoleAssigned = $false }
        }
    }
}

# --- Final verification pass, whatever happened above --------------------------
# ⭐ Report the STATE, not the intent. This runs even on a re-run over existing accounts.
if ($Apply -and $gaRole) {
    Write-Host ""
    Write-Host "=== Verification: who actually holds Global Administrator? ===" -ForegroundColor Cyan
    $gaMembers = @(Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All -ErrorAction SilentlyContinue)
    $gaUpns = @($gaMembers | ForEach-Object { $_.AdditionalProperties.userPrincipalName })
    $gaUpns | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    foreach ($c in $created) {
        if ($c.Upn -notin $gaUpns) {
            Write-Host "  [FAIL  ] $($c.Upn) is NOT a Global Administrator." -ForegroundColor Red
        }
    }
}

Write-Host ""

$fresh = @($created | Where-Object Password -ne '(unchanged)')

if ($Apply -and $fresh.Count) {
    # --- Write credentials to a locked-down file, NEVER to stdout ---------------
    if (-not (Test-Path $CredentialPath)) {
        New-Item -ItemType Directory -Path $CredentialPath -Force | Out-Null
    }

    # ⭐ ACL: this user only. Break inheritance, remove everyone else.
    #    00-foundations/linux-and-windows sec.3 - an explicit, non-inherited ACE is a
    #    deliberate act, and this is one of the few places that is exactly what you want.
    $acl = Get-Acl $CredentialPath
    $acl.SetAccessRuleProtection($true, $false)          # protected, drop inherited rules
    $acl.Access | ForEach-Object { [void]$acl.RemoveAccessRule($_) }
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
    Set-Acl -Path $CredentialPath -AclObject $acl

    $file = Join-Path $CredentialPath ("breakglass-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    $lines = @(
        "Break-glass credentials - $((Get-MgOrganization).DisplayName)"
        "Tenant domain : $domain"
        "Created       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
        "Created by    : $($ctx.Account)"
        ""
        "TRANSFER THESE TO A PASSWORD MANAGER OR SEALED ENVELOPE, THEN DELETE THIS FILE."
        "Real-world practice splits them across two custodians."
        ""
    ) + ($fresh | ForEach-Object { "{0}`r`n    {1}`r`n" -f $_.Upn, $_.Password })

    Set-Content -Path $file -Value $lines -Encoding utf8
    (Get-Item $file).Attributes = 'Normal'

    Write-Host "=== CREDENTIALS WRITTEN ===================================" -ForegroundColor Yellow
    Write-Host "  $file" -ForegroundColor White
    Write-Host ""
    Write-Host "  ⭐ Passwords were NOT printed. stdout reaches shell history, scrollback," -ForegroundColor DarkGray
    Write-Host "     screen shares, CI logs and agent transcripts. A break-glass credential's" -ForegroundColor DarkGray
    Write-Host "     value is provable sole custody - broadcasting it destroys that at creation." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Folder ACL is restricted to $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)." -ForegroundColor DarkGray
    Write-Host "  ⚠ It is OUTSIDE the repo so it cannot be committed. Move to a password" -ForegroundColor Red
    Write-Host "    manager and delete the file today." -ForegroundColor Red
    Write-Host ""
}

# --- The steps the script deliberately does NOT do for you ---------------------
Write-Host "=== Remaining steps - do these before writing any CA policy ===" -ForegroundColor Cyan
@(
    'Exclude BOTH accounts from EVERY Conditional Access policy - no exceptions.'
    'Do NOT make them PIM-eligible. PIM activation can fail; that is the scenario they exist for.'
    'Do NOT license them (they need no mailbox and no Intune).'
    'Create an alert on sign-in by these accounts - any use is an incident until proven otherwise.'
    'Test one of them now, in a private window, and record that it worked.'
    'Diarise a quarterly test. An untested break-glass is a hope, not a control.'
) | ForEach-Object { Write-Host "  [] $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "Evidence to capture -> 30-identity-and-nhi/pim-and-access-reviews/security/" -ForegroundColor DarkGray
Write-Host "  break-glass design note + proof of CA exclusion + successful test sign-in date." -ForegroundColor DarkGray
Write-Host ""

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
    Passwords are printed ONCE and never written to disk by this script. Put them somewhere real
    before you close the window. If you lose them, delete the accounts and re-run.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Apply,
    [string]$Prefix = 'breakglass'
)

$ErrorActionPreference = 'Stop'

$Scopes = @(
    'User.ReadWrite.All'
    'RoleManagement.ReadWrite.Directory'
    'Directory.ReadWrite.All'
    'Policy.Read.All'
)

if (-not (Get-MgContext)) { Connect-MgGraph -Scopes $Scopes -NoWelcome }
$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected to Graph." }

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
        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $gaRole.Id `
            -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.Id)" }

        Write-Host "  [OK    ] Created $upn with permanent Global Administrator" -ForegroundColor Green
        $created += [pscustomobject]@{ Upn = $upn; Id = $u.Id; Password = $pw }
    }
    catch {
        Write-Host "  [FAIL  ] $upn -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

if ($Apply -and ($created | Where-Object Password -ne '(unchanged)')) {
    Write-Host "=== PASSWORDS - SHOWN ONCE ================================" -ForegroundColor Red
    $created | Where-Object Password -ne '(unchanged)' |
        ForEach-Object { Write-Host ("  {0}`n    {1}" -f $_.Upn, $_.Password) -ForegroundColor White }
    Write-Host ""
    Write-Host "  Store these offline NOW. This script does not write them to disk." -ForegroundColor Red
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

<#
.SYNOPSIS
    Repair break-glass accounts that were created WITHOUT the Global Administrator role.

.DESCRIPTION
    ⭐ Written because Day1-New-BreakGlass.ps1 shipped with a real bug on 2026-08-12:

      New-MgDirectoryRoleMemberByRef wrote a NON-TERMINATING error (403
      Authorization_RequestDenied). The surrounding catch never fired, execution continued, and
      the script printed "[OK] Created ... with permanent Global Administrator" over a role
      assignment that had not happened.

    Two lessons, and both are in this repo already:
      * 00-foundations/cli-and-scripting sec.5 - the default $ErrorActionPreference does not
        stop a loop on a non-terminating error. -ErrorAction Stop is load-bearing.
      * 20-azure-platform/deployment-strategies sec.2 - DEPLOYED IS NOT ENFORCED. A control is
        not real because an API was called; it is real because you read the state back.

    ⭐ The root cause of the 403 itself is worth more than the bug: the script reused an
    existing Graph session that lacked RoleManagement.ReadWrite.Directory. On a delegated
    token, effective rights are the INTERSECTION of granted scopes and the caller's directory
    role - and Authorization_RequestDenied looks IDENTICAL whether the scope or the role is
    missing. Telling those apart is the skill.

    This script diagnoses which of the two it is, then repairs.

.PARAMETER Apply
    Actually assign the role. Without it, diagnoses only.

.EXAMPLE
    .\Repair-BreakGlassRole.ps1
    .\Repair-BreakGlassRole.ps1 -Apply
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Apply,
    [string]$Prefix = 'breakglass'
)

$ErrorActionPreference = 'Stop'

$Required = @('User.ReadWrite.All','RoleManagement.ReadWrite.Directory','Directory.ReadWrite.All')

# --- 1. Diagnose the token BEFORE blaming the role ----------------------------
$ctx = Get-MgContext
Write-Host ""
Write-Host "=== 1. Token scopes =======================================" -ForegroundColor Cyan
if (-not $ctx) {
    Write-Host "  No context. Connecting with the full scope set." -ForegroundColor Yellow
    Connect-MgGraph -Scopes $Required -NoWelcome
    $ctx = Get-MgContext
} else {
    Write-Host "  Account: $($ctx.Account)" -ForegroundColor Gray
    $missing = @($Required | Where-Object { $_ -notin $ctx.Scopes })
    if ($missing.Count) {
        Write-Host "  [CAUSE] Session is MISSING: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "          ⭐ This alone produces 403 Authorization_RequestDenied," -ForegroundColor DarkGray
        Write-Host "            regardless of your directory role. Reconnecting." -ForegroundColor DarkGray
        Connect-MgGraph -Scopes $Required -NoWelcome
        $ctx = Get-MgContext
    } else {
        Write-Host "  [OK   ] All required scopes present." -ForegroundColor Green
    }
}

$still = @($Required | Where-Object { $_ -notin $ctx.Scopes })
if ($still.Count) { throw "Consent not granted for: $($still -join ', ')" }

# --- 2. Diagnose the ROLE - the other half of the intersection ----------------
Write-Host ""
Write-Host "=== 2. Does the CALLER hold Global Administrator? =========" -ForegroundColor Cyan
$gaTemplate = '62e90394-69f5-4237-9190-012177145e10'
$gaRole = Get-MgDirectoryRole -Filter "roleTemplateId eq '$gaTemplate'" -ErrorAction SilentlyContinue
if (-not $gaRole) {
    if ($Apply) { $gaRole = New-MgDirectoryRole -RoleTemplateId $gaTemplate }
    else { Write-Host "  Global Administrator role not activated in this tenant." -ForegroundColor Yellow }
}

$me = Get-MgUser -UserId $ctx.Account -ErrorAction SilentlyContinue
$gaMembers = @(Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All -ErrorAction SilentlyContinue)
$gaUpns = @($gaMembers | ForEach-Object { $_.AdditionalProperties.userPrincipalName })

if ($me -and $me.UserPrincipalName -in $gaUpns) {
    Write-Host "  [OK   ] $($me.UserPrincipalName) IS a Global Administrator." -ForegroundColor Green
} else {
    Write-Host "  [CAUSE] $($ctx.Account) is NOT a permanent Global Administrator member." -ForegroundColor Red
    Write-Host "          ⭐ If you hold it as a PIM-ELIGIBLE assignment you must ACTIVATE it first -" -ForegroundColor Yellow
    Write-Host "            eligible is not active, and the token carries only what is active." -ForegroundColor Yellow
}

# --- 3. Current state of the break-glass accounts -----------------------------
Write-Host ""
Write-Host "=== 3. Break-glass accounts ===============================" -ForegroundColor Cyan
$bg = @(Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,AccountEnabled |
        Where-Object { $_.UserPrincipalName -like "$Prefix*" })

if (-not $bg.Count) { throw "No accounts matching '$Prefix*' found." }

$needsRole = @()
foreach ($u in $bg) {
    $hasGa = $u.Id -in @($gaMembers.Id)
    $mark  = if ($hasGa) { '[OK   ]' } else { '[FAIL ]' }
    $col   = if ($hasGa) { 'Green' } else { 'Red' }
    Write-Host ("  {0} {1}  GlobalAdmin={2}" -f $mark, $u.UserPrincipalName, $hasGa) -ForegroundColor $col
    if (-not $hasGa) { $needsRole += $u }
}

if (-not $needsRole.Count) {
    Write-Host ""
    Write-Host "  Nothing to repair - all break-glass accounts hold the role." -ForegroundColor Green
    return
}

# --- 4. Repair ----------------------------------------------------------------
Write-Host ""
Write-Host "=== 4. Repair =============================================" -ForegroundColor Cyan
foreach ($u in $needsRole) {
    if (-not $Apply) {
        Write-Host "  [DRYRUN] Assign Global Administrator to $($u.UserPrincipalName)" -ForegroundColor Yellow
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Assign Global Administrator')) { continue }

    try {
        New-MgDirectoryRoleMemberByRef -DirectoryRoleId $gaRole.Id -ErrorAction Stop `
            -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.Id)" }

        Start-Sleep -Seconds 2
        $ok = @(Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All -EA SilentlyContinue |
                Where-Object Id -eq $u.Id).Count -gt 0

        if ($ok) { Write-Host "  [OK    ] $($u.UserPrincipalName) - VERIFIED Global Administrator" -ForegroundColor Green }
        else     { Write-Host "  [FAIL  ] $($u.UserPrincipalName) - call succeeded, verification did not" -ForegroundColor Red }
    }
    catch {
        Write-Host "  [FAIL  ] $($u.UserPrincipalName) -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "⭐ Now TEST one account in a private window before writing any CA policy." -ForegroundColor Yellow
Write-Host "   An untested break-glass is a hope, not a control." -ForegroundColor Yellow
Write-Host ""

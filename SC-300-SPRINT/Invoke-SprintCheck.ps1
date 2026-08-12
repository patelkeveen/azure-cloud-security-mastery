<#
.SYNOPSIS
    Self-check for the SC-300 sprint. Tells you exactly what is ready, what is not, and what to
    run next - with no interpretation required from anyone else.

.DESCRIPTION
    ⭐ This script exists so the sprint is self-sufficient. Run it at the start and end of every
    day. It answers, in order:

        1. Am I connected, and with which scopes?
        2. Do break-glass accounts exist AND hold the role AND are they excluded from CA?
        3. Are licences assigned to the users that matter?
        4. Is the telemetry that needs time actually running?
        5. Is Azure available?
        6. How much evidence exists, and how close is the first WRITTEN topic?
        7. What should I do next?

    Every FAIL prints the fix inline or points at a section of TROUBLESHOOTING.md.
    READ-ONLY - changes nothing.

.EXAMPLE
    .\Invoke-SprintCheck.ps1
    .\Invoke-SprintCheck.ps1 -Day 3
#>
[CmdletBinding()]
param([int]$Day)

$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot -Parent
$pass = 0; $fail = 0; $warn = 0

function R {
    param([string]$Name, [ValidateSet('PASS','FAIL','WARN','INFO')][string]$State, [string]$Detail, [string]$Fix)
    $c = switch ($State) { 'PASS' {'Green'} 'FAIL' {'Red'} 'WARN' {'Yellow'} default {'Gray'} }
    Write-Host ("  [{0,-4}] {1}" -f $State, $Name) -ForegroundColor $c
    if ($Detail) { Write-Host ("         {0}" -f $Detail) -ForegroundColor DarkGray }
    if ($Fix -and $State -ne 'PASS') { Write-Host ("         FIX: {0}" -f $Fix) -ForegroundColor Cyan }
    switch ($State) { 'PASS' {$script:pass++} 'FAIL' {$script:fail++} 'WARN' {$script:warn++} }
}

Write-Host ""
Write-Host "SC-300 SPRINT SELF-CHECK    $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
$left = [int]((Get-Date '2026-09-10') - (Get-Date)).TotalDays
Write-Host "Trial expires 2026-09-10 - $left day(s) left" -ForegroundColor $(if($left -le 7){'Red'}elseif($left -le 14){'Yellow'}else{'Green'})
Write-Host ("=" * 62)

# --- 1. Graph -----------------------------------------------------------------
Write-Host "`n1. Graph connection" -ForegroundColor White
$ctx = try { Get-MgContext } catch { $null }
if (-not $ctx) {
    R 'Connected' 'FAIL' 'No Graph context.' "Connect-MgGraph -Scopes 'User.ReadWrite.All','RoleManagement.ReadWrite.Directory','Directory.ReadWrite.All','Policy.ReadWrite.ConditionalAccess'"
} else {
    R 'Connected' 'PASS' "$($ctx.Account)"
    $need = @('Directory.Read.All','User.Read.All')
    $miss = @($need | Where-Object { $_ -notin $ctx.Scopes })
    if ($miss.Count) { R 'Core scopes' 'WARN' "missing: $($miss -join ', ')" 'Disconnect-MgGraph then reconnect with the full list. TROUBLESHOOTING.md sec.1' }
    else { R 'Core scopes' 'PASS' "$(@($ctx.Scopes).Count) scopes held" }
}

if ($ctx) {
# --- 2. Break-glass -----------------------------------------------------------
Write-Host "`n2. Break-glass" -ForegroundColor White
$bg = @(Get-MgUser -All -Property Id,UserPrincipalName,AccountEnabled -EA SilentlyContinue |
        Where-Object { $_.UserPrincipalName -match 'break.?glass|emergency|bg-' })

if ($bg.Count -lt 2) {
    R 'Two accounts exist' 'FAIL' "found $($bg.Count)" '.\Day1-New-BreakGlass.ps1 -Apply'
} else {
    R 'Two accounts exist' 'PASS' ($bg.UserPrincipalName -join ', ')

    $gaRole = Get-MgDirectoryRole -Filter "roleTemplateId eq '62e90394-69f5-4237-9190-012177145e10'" -EA SilentlyContinue
    if ($gaRole) {
        $gaIds = @((Get-MgDirectoryRoleMember -DirectoryRoleId $gaRole.Id -All -EA SilentlyContinue).Id)
        $noRole = @($bg | Where-Object { $_.Id -notin $gaIds })
        if ($noRole.Count) {
            R 'Hold Global Administrator' 'FAIL' "$($noRole.UserPrincipalName -join ', ') have NO role" '.\Repair-BreakGlassRole.ps1 -Apply'
        } else { R 'Hold Global Administrator' 'PASS' 'verified against role membership' }
    }

    $ca = @(Get-MgIdentityConditionalAccessPolicy -All -EA SilentlyContinue)
    $enabled = @($ca | Where-Object State -ne 'disabled')
    if (-not $enabled.Count) {
        R 'Excluded from enabled CA' 'PASS' 'no enabled policies yet - clean start'
    } else {
        $bad = foreach ($p in $enabled) {
            if (@($bg.Id | Where-Object { $_ -notin @($p.Conditions.Users.ExcludeUsers) }).Count) { $p.DisplayName }
        }
        if ($bad) { R 'Excluded from enabled CA' 'FAIL' ($bad -join '; ') 'Exclude both before enabling. TROUBLESHOOTING.md sec.5' }
        else { R 'Excluded from enabled CA' 'PASS' "$($enabled.Count) enabled policies checked" }
    }
    R 'Tested by signing in' 'INFO' 'Only you can confirm. Private window, record the date.'
}

# --- 3. Licensing -------------------------------------------------------------
Write-Host "`n3. Licensing" -ForegroundColor White
$skus = @(Get-MgSubscribedSku -EA SilentlyContinue)
$e5 = $skus | Where-Object SkuPartNumber -eq 'SPE_E5'
if (-not $e5) { R 'M365 E5 present' 'FAIL' 'SPE_E5 not found' 'Office 365 E5 alone has no Entra P2.' }
else {
    R 'M365 E5 present' 'PASS' "$($e5.ConsumedUnits)/$($e5.PrepaidUnits.Enabled) assigned"
    if ($e5.ConsumedUnits -eq 0) {
        R 'Seats assigned' 'FAIL' 'zero assigned - every feature is inert' 'TROUBLESHOOTING.md sec.3 (UsageLocation FIRST)'
    } else { R 'Seats assigned' 'PASS' }
}

# --- 4. Telemetry that needs time --------------------------------------------
Write-Host "`n4. Telemetry (needs days of baseline)" -ForegroundColor White
$risk = @($ca | Where-Object { $_.Conditions.SignInRiskLevels -or $_.Conditions.UserRiskLevels })
if ($risk.Count) { R 'Identity Protection policies' 'PASS' "$($risk.Count) risk policies exist" }
else { R 'Identity Protection policies' 'FAIL' 'none - Day 7 will have no data' '.\Day1-Enable-Telemetry.ps1 -Apply' }

$det = @(Get-MgRiskDetection -Top 5 -EA SilentlyContinue)
R 'Risk detections so far' 'INFO' "$($det.Count) visible (needs sign-in volume over days)"

$exo = $null -ne (Get-Command Get-AdminAuditLogConfig -EA SilentlyContinue)
if ($exo) {
    $ual = (Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled
    if ($ual) { R 'Unified audit log' 'PASS' } else { R 'Unified audit log' 'FAIL' 'off - captures forward only' 'Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true' }
} else { R 'Unified audit log' 'WARN' 'ExchangeOnline not connected' 'Connect-ExchangeOnline' }

R 'Portal-side (MDE/MDCA/Insider Risk)' 'INFO' 'Not scriptable. DAY-1.md Lab 1.3 checklist.'

# --- 5. Seeded org ------------------------------------------------------------
Write-Host "`n5. Lab org" -ForegroundColor White
$users = @(Get-MgUser -All -Property UserPrincipalName,UserType -EA SilentlyContinue)
$members = @($users | Where-Object UserType -ne 'Guest')
if ($members.Count -ge 10) { R 'Seeded users' 'PASS' "$($members.Count) members" }
else { R 'Seeded users' 'WARN' "$($members.Count) members - too few for governance labs" '..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 -Apply' }

$dyn = @(Get-MgGroup -All -Filter "groupTypes/any(c:c eq 'DynamicMembership')" -EA SilentlyContinue)
if ($dyn.Count) { R 'Dynamic groups' 'PASS' "$($dyn.Count) groups" } else { R 'Dynamic groups' 'WARN' 'none' 'Seed-LabTenant.ps1 -Apply' }
}

# --- 6. Azure -----------------------------------------------------------------
Write-Host "`n6. Azure" -ForegroundColor White
$subs = @()
try {
    $acc = az account list --only-show-errors 2>$null | ConvertFrom-Json
    $subs = @($acc | Where-Object { $_.name -ne 'N/A(tenant level account)' -and $_.id -ne $_.tenantId })
} catch { }
if ($subs.Count) {
    R 'Subscription' 'PASS' ($subs.name -join ', ')
    R 'Unblocked' 'INFO' 'Sentinel, Key Vault, PIM for Azure resources, Labs 11/16/27'
} else {
    R 'Subscription' 'WARN' 'none visible to the CLI' 'az login; az account list --refresh -o table'
}

# --- 7. Evidence --------------------------------------------------------------
Write-Host "`n7. Evidence" -ForegroundColor White
$FACETS = 'lab','security','operations','break-fix','customer-use-cases','architecture-decisions'
$topics = Get-ChildItem $repo -Directory | Where-Object Name -match '^\d\d-' |
          ForEach-Object { Get-ChildItem $_.FullName -Directory -EA SilentlyContinue }
$scored = foreach ($t in $topics) {
    $n = @($FACETS | Where-Object { $fp = Join-Path $t.FullName $_
        (Test-Path $fp) -and @(Get-ChildItem $fp -File -Recurse -EA SilentlyContinue | Where-Object Name -ne '.gitkeep').Count }).Count
    if ($n -gt 0) { [pscustomobject]@{ Topic = $t.Name; Facets = $n } }
}
$written = @($scored | Where-Object Facets -ge 3)
$partial = @($scored | Where-Object { $_.Facets -in 1,2 })

if ($written.Count) { R 'WRITTEN topics' 'PASS' "$($written.Count): $($written.Topic -join ', ')" }
else { R 'WRITTEN topics' 'WARN' '0 - needs >=3 of 6 facets on any topic' 'Use New-LabEvidence.ps1 after every lab' }

if ($partial.Count) {
    R 'Closest to WRITTEN' 'INFO' (($partial | Sort-Object Facets -Descending | Select-Object -First 3 |
        ForEach-Object { "$($_.Topic) ($($_.Facets)/6)" }) -join ', ')
}

# --- Summary ------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 62)
Write-Host ("PASS {0}   FAIL {1}   WARN {2}" -f $pass, $fail, $warn) -ForegroundColor $(if($fail){'Red'}elseif($warn){'Yellow'}else{'Green'})
Write-Host ""
Write-Host "NEXT:" -ForegroundColor Cyan
if ($fail -gt 0) {
    Write-Host "  Clear the FAIL lines above first - each one prints its own fix." -ForegroundColor Red
} else {
    $d = if ($Day) { $Day } else { 1 }
    Write-Host "  Open DAY-$d.md and work through it." -ForegroundColor Green
    Write-Host "  Official labs for that day: OFFICIAL-LABS-MAP.md" -ForegroundColor Green
    Write-Host "  Capture evidence after each lab: New-LabEvidence.ps1" -ForegroundColor Green
    Write-Host "  Anything unexpected: TROUBLESHOOTING.md" -ForegroundColor Green
}
Write-Host ""

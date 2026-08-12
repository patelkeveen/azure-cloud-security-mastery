<#
.SYNOPSIS
    Day 1: switch on everything that LEARNS, so it accumulates data while you do other work.

.DESCRIPTION
    ⭐ The constraint on a 30-day trial is DATA LATENCY, not difficulty.

    Identity Protection, Defender for Endpoint/ASR audit mode, Defender for Cloud Apps
    discovery, Defender for Identity, Insider Risk, unified audit and MailItemsAccessed all
    capture FROM THE MOMENT THEY ARE ENABLED FORWARD. Several need days of baseline before
    they produce anything worth looking at.

    Follow a syllabus linearly and you reach Defender for Cloud Apps on day 22 with eight
    days of telemetry instead of thirty. So: enable the slow things first, then spend the
    remaining days on instant work while data accumulates in the background.

    What this script does, in dependency order:
      1. Verifies break-glass accounts exist and are excluded from CA   (refuses to proceed otherwise)
      2. Enables the unified audit log
      3. Turns Identity Protection risk policies on in REPORT-ONLY
      4. Reports which Defender workloads still need portal-side enablement (with links)

    DRY RUN BY DEFAULT - nothing changes unless you pass -Apply.
    Idempotent: safe to re-run.

    See 00-foundations/cli-and-scripting/README.md sec.3 for why find-then-fix is separated,
    and why -WhatIf only works if the author wired it up. It is wired up here.

.PARAMETER Apply
    Actually make changes. Without it, prints the plan.

.PARAMETER SkipBreakGlassCheck
    ⚠ Override the safety gate. Only if you have verified break-glass another way.

.EXAMPLE
    .\Day1-Enable-Telemetry.ps1                # see the plan
    .\Day1-Enable-Telemetry.ps1 -Apply         # execute

.NOTES
    Requires Global Administrator plus (for the audit step) Exchange Online management.
    Some Defender workloads have no supported Graph/PowerShell enablement path and are
    reported as manual portal steps rather than silently skipped.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$Apply,
    [switch]$SkipBreakGlassCheck
)

$ErrorActionPreference = 'Stop'

$Scopes = @(
    'Policy.ReadWrite.ConditionalAccess'
    'Policy.Read.All'
    'IdentityRiskyUser.Read.All'
    'User.Read.All'
    'Directory.Read.All'
    'Application.Read.All'
)

if (-not (Get-MgContext)) {
    Write-Host "Connecting to Graph..." -ForegroundColor Cyan
    try {
        Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
    } catch {
        $azToken = az account get-access-token --resource-type ms-graph --query accessToken -o tsv 2>$null
        if ($azToken) {
            Write-Host "Connecting via active Azure CLI session token..." -ForegroundColor Green
            $sec = ConvertTo-SecureString $azToken -AsPlainText -Force
            Connect-MgGraph -AccessToken $sec
        } else {
            Write-Host "Interactive authentication failed or running in non-interactive session. Switching to Device Code authentication..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $Scopes -UseDeviceAuthentication
        }
    }
}
$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected to Graph." }

$mode = if ($Apply) { 'APPLY' } else { 'DRY RUN - pass -Apply to execute' }
Write-Host ""
Write-Host "Account : $($ctx.Account)" -ForegroundColor Green
Write-Host "Mode    : $mode" -ForegroundColor $(if ($Apply) { 'Green' } else { 'Yellow' })
Write-Host ""

function Step {
    param([string]$What, [scriptblock]$Do)
    if (-not $Apply) { Write-Host "  [DRYRUN ] $What" -ForegroundColor Yellow; return }
    if (-not $PSCmdlet.ShouldProcess($What)) { Write-Host "  [SKIP   ] $What" -ForegroundColor DarkGray; return }
    try   { $r = & $Do; Write-Host "  [OK     ] $What" -ForegroundColor Green; return $r }
    catch { Write-Host "  [FAIL   ] $What -> $($_.Exception.Message)" -ForegroundColor Red }
}

# =============================================================================
# 0. SAFETY GATE - break-glass before any policy work
# =============================================================================
# 30-identity-and-nhi/conditional-access: grant controls default to AND, and a policy
# targeting "All users" includes YOU. Break-glass must exist and be excluded BEFORE the
# first policy, not after. This gate refuses to continue otherwise, on purpose.
Write-Host "=== 0. Break-glass safety gate ============================" -ForegroundColor Cyan

if ($SkipBreakGlassCheck) {
    Write-Host "  [WARN] Gate overridden by -SkipBreakGlassCheck." -ForegroundColor Yellow
} else {
    $bg = Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,OnPremisesSyncEnabled |
          Where-Object { $_.UserPrincipalName -match 'break.?glass|emergency|bg-' }

    if (@($bg).Count -lt 2) {
        Write-Host "  [STOP] Fewer than 2 break-glass accounts found." -ForegroundColor Red
        Write-Host "         Run Day1-New-BreakGlass.ps1 -Apply first." -ForegroundColor Red
        Write-Host "         Rationale: a CA policy scoped to All users will lock you out of your own" -ForegroundColor DarkGray
        Write-Host "         tenant, and a trial tenant has no support path to recover it." -ForegroundColor DarkGray
        throw "Break-glass gate failed. This is deliberate."
    }

    Write-Host "  [OK  ] Break-glass accounts found:" -ForegroundColor Green
    $bg | ForEach-Object { Write-Host "         $($_.UserPrincipalName)" -ForegroundColor DarkGray }

    # Are they excluded from every enabled CA policy?
    $caPolicies = @(Get-MgIdentityConditionalAccessPolicy -All -ErrorAction SilentlyContinue)
    $bgIds = @($bg.Id)
    $unprotected = foreach ($p in ($caPolicies | Where-Object State -ne 'disabled')) {
        $excluded = @($p.Conditions.Users.ExcludeUsers)
        $missing  = @($bgIds | Where-Object { $_ -notin $excluded })
        if ($missing.Count) { $p.DisplayName }
    }
    if ($unprotected) {
        Write-Host "  [WARN] Break-glass NOT excluded from these enabled policies:" -ForegroundColor Yellow
        $unprotected | ForEach-Object { Write-Host "         $_" -ForegroundColor Yellow }
        Write-Host "         Fix before enabling any policy. This is the lockout path." -ForegroundColor Yellow
    } elseif ($caPolicies.Count -eq 0) {
        Write-Host "  [OK  ] No CA policies yet - clean start." -ForegroundColor Green
    } else {
        Write-Host "  [OK  ] Break-glass excluded from all enabled CA policies." -ForegroundColor Green
    }
}
Write-Host ""

# =============================================================================
# 1. Unified audit log - captures FORWARD ONLY
# =============================================================================
Write-Host "=== 1. Unified audit log ==================================" -ForegroundColor Cyan
Write-Host "    Captures forward only. Every hour it is off is an hour you cannot investigate." -ForegroundColor DarkGray

$exoAvailable = $null -ne (Get-Command Get-AdminAuditLogConfig -ErrorAction SilentlyContinue)
if (-not $exoAvailable) {
    Write-Host "  [SKIP] ExchangeOnlineManagement not connected." -ForegroundColor Yellow
    Write-Host "         Run: Connect-ExchangeOnline   then re-run this script." -ForegroundColor DarkGray
} else {
    $cfg = Get-AdminAuditLogConfig
    if ($cfg.UnifiedAuditLogIngestionEnabled) {
        Write-Host "  [OK  ] Unified audit log already enabled." -ForegroundColor Green
    } else {
        Step "Enable unified audit log ingestion" {
            Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true
        }
    }

    # MailItemsAccessed - the action that answers "what did the attacker READ?"
    # 40-microsoft-365-platform/exchange-online/README.md sec.5
    Write-Host "  [NOTE] Verify MailItemsAccessed is in the audited action set per mailbox:" -ForegroundColor DarkGray
    Write-Host "         Get-Mailbox <upn> | Select-Object -Expand AuditOwner" -ForegroundColor DarkGray
}
Write-Host ""

# =============================================================================
# 2. Identity Protection - report-only first (watch first)
# =============================================================================
# RETENTION.md sec.3b "watch first": every enforcement control has an observe mode, and
# deploying straight to enforce is the recurring outage. Risk policies especially - a
# sign-in risk policy at Enforce on day one will lock out your own seed users.
Write-Host "=== 2. Identity Protection risk policies ==================" -ForegroundColor Cyan
Write-Host "    Report-only first. These need SIGN-IN VOLUME before they say anything useful." -ForegroundColor DarkGray

$riskPolicies = @(
    @{
        Name = 'SC300 - Sign-in risk (report-only)'
        Body = @{
            displayName = 'SC300 - Sign-in risk (report-only)'
            state       = 'enabledForReportingButNotEnforced'
            conditions  = @{
                users        = @{ includeUsers = @('All'); excludeUsers = @($bgIds) }
                applications = @{ includeApplications = @('All') }
                signInRiskLevels = @('high','medium')
            }
            grantControls = @{ operator = 'OR'; builtInControls = @('mfa') }
        }
    },
    @{
        Name = 'SC300 - User risk (report-only)'
        Body = @{
            displayName = 'SC300 - User risk (report-only)'
            state       = 'enabledForReportingButNotEnforced'
            conditions  = @{
                users        = @{ includeUsers = @('All'); excludeUsers = @($bgIds) }
                applications = @{ includeApplications = @('All') }
                userRiskLevels = @('high')
            }
            grantControls = @{ operator = 'AND'; builtInControls = @('mfa', 'passwordChange') }
        }
    }
)

$existing = @(Get-MgIdentityConditionalAccessPolicy -All -ErrorAction SilentlyContinue)
foreach ($rp in $riskPolicies) {
    if ($existing.DisplayName -contains $rp.Name) {
        Write-Host "  [OK  ] Exists: $($rp.Name)" -ForegroundColor Green
        continue
    }
    Step "Create CA policy '$($rp.Name)' in report-only" {
        New-MgIdentityConditionalAccessPolicy -BodyParameter $rp.Body
    }
}
Write-Host ""

# =============================================================================
# 3. Portal-side enablement - reported honestly, not silently skipped
# =============================================================================
Write-Host "=== 3. Manual portal steps (no supported script path) =====" -ForegroundColor Cyan
Write-Host "    Do these TODAY. Each one only starts learning when you click it." -ForegroundColor DarkGray
Write-Host ""

$manual = @(
    @{ N='Defender for Endpoint'; W='Onboard THIS laptop; set ASR rules to AUDIT mode';
       U='https://security.microsoft.com/securitysettings/endpoints/onboarding';
       Why='EDR telemetry + ASR audit both need days of device activity' }
    @{ N='Defender for Cloud Apps'; W='Enable the Microsoft 365 app connector';
       U='https://security.microsoft.com/cloudapps/app-connectors';
       Why='Discovery and anomaly detection need a usage baseline' }
    @{ N='Defender for Identity'; W='Only if you have a domain controller to sensor';
       U='https://security.microsoft.com/settings/identities';
       Why='Sensor baseline learning period' }
    @{ N='Insider Risk Management'; W='Enable + turn ON pseudonymisation';
       U='https://purview.microsoft.com/insiderriskmgmt';
       Why='Indicators need activity history. Pseudonymisation: purview-compliance sec.4' }
    @{ N='Purview audit retention'; W='Confirm retention matches what an investigation needs';
       U='https://purview.microsoft.com/audit/auditsearch';
       Why='Licence-gated, and decided before you need it' }
    @{ N='Attack simulation training'; W='Launch one campaign now';
       U='https://security.microsoft.com/attacksimulator';
       Why='Campaigns take days to run and report' }
)

foreach ($m in $manual) {
    Write-Host ("  [] {0}" -f $m.N) -ForegroundColor White
    Write-Host ("       do : {0}" -f $m.W) -ForegroundColor Gray
    Write-Host ("       why: {0}" -f $m.Why) -ForegroundColor DarkGray
    Write-Host ("       url: {0}" -f $m.U) -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host "=== Done ==================================================" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host "  DRY RUN. Re-run with -Apply once the plan above looks right." -ForegroundColor Yellow
} else {
    Write-Host "  Telemetry is now accumulating. Stop here for today." -ForegroundColor Green
    Write-Host "  Next: Seed-LabTenant.ps1 -Apply  (a pristine tenant generates no signal)" -ForegroundColor Green
}
Write-Host ""

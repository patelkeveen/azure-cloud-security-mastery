<#
.SYNOPSIS
    Verify what the M365 E5 trial ACTUALLY provisioned, before planning a single lab.

.DESCRIPTION
    A confirmation page is a claim. Service plans are the evidence.

    This script answers four questions, in the order that matters:
      1. Which SKUs exist in the tenant, and how many seats?
      2. Which security service plans inside them are PROVISIONED (not PendingProvisioning)?
      3. Who is actually LICENSED - because a licence in the tenant does nothing until assigned?
      4. What is still blocked (no Azure subscription => no Sentinel, no Defender for Cloud)?

    READ-ONLY. It creates and changes nothing. Safe to run repeatedly.

    Why this exists: 40-microsoft-365-platform/licensing-and-service-limits/README.md sec.1 -
    capability is gated by SKU and the gate is SILENT. A control configured for users who are
    not licensed applies to some of them and quietly does not apply to the rest, with no error.

.EXAMPLE
    .\Day0-Verify-Tenant.ps1
    .\Day0-Verify-Tenant.ps1 -OutFile .\evidence\day0-licence-state.json

.NOTES
    Requires: Microsoft.Graph module. Delegated scopes below are all *.Read.
#>
[CmdletBinding()]
param(
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

$Scopes = @(
    'Organization.Read.All'
    'Directory.Read.All'
    'User.Read.All'
    'Policy.Read.All'
)

if (-not (Get-MgContext)) {
    Write-Host "Connecting to Graph (read-only scopes)..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $Scopes -NoWelcome
}
$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected to Graph." }

$org = Get-MgOrganization
Write-Host ""
Write-Host "Tenant  : $($org.DisplayName)" -ForegroundColor Green
Write-Host "TenantId: $($org.Id)"
Write-Host "Account : $($ctx.Account)"
Write-Host "Checked : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-Host ""

# --- 1. SKUs -------------------------------------------------------------------
Write-Host "=== 1. SKUs in the tenant =================================" -ForegroundColor Cyan
$skus = Get-MgSubscribedSku
$skuRows = $skus | Select-Object SkuPartNumber, SkuId,
    @{n='Enabled'; e={ $_.PrepaidUnits.Enabled }},
    @{n='Assigned';e={ $_.ConsumedUnits }},
    @{n='Spare';   e={ $_.PrepaidUnits.Enabled - $_.ConsumedUnits }},
    @{n='Warning'; e={ $_.PrepaidUnits.Warning }}
$skuRows | Sort-Object Enabled -Descending | Format-Table -AutoSize

$e5 = $skus | Where-Object SkuPartNumber -eq 'SPE_E5'
if ($e5) {
    Write-Host "  [OK  ] SPE_E5 (Microsoft 365 E5) present - $($e5.PrepaidUnits.Enabled) seat(s)." -ForegroundColor Green
} else {
    Write-Host "  [WARN] SPE_E5 NOT found. M365 E5 = Office 365 E5 + EMS E5 + Windows E5." -ForegroundColor Yellow
    Write-Host "         If you only see ENTERPRISEPREMIUM* you have Office 365 E5, which has NO Entra P1/P2." -ForegroundColor Yellow
}
Write-Host ""

# --- 2. Service plans that gate the SC-300 / SC-200 labs -----------------------
# The plan-name fragments that matter. Each maps to work you cannot do without it.
$gates = [ordered]@{
    'AAD_PREMIUM_P2'   = 'Entra ID P2 - PIM, Identity Protection, access reviews   [SC-300 CORE]'
    'AAD_PREMIUM'      = 'Entra ID P1 - Conditional Access                          [SC-300 CORE]'
    'INTUNE_A'         = 'Intune - device compliance -> CA                          [SC-300]'
    'WINDEFATP'        = 'Defender for Endpoint P2                                  [SC-200]'
    'ATA'              = 'Defender for Identity                                     [SC-200]'
    'ADALLOM_S_STANDA' = 'Defender for Cloud Apps                                   [SC-200]'
    'ATP_ENTERPRISE'   = 'Defender for Office 365 P2                                [SC-200]'
    'THREAT_INTELLIGENCE' = 'Defender for Office 365 P2 (threat intel)              [SC-200]'
    'PREMIUM_ENCRYPTION'  = 'Purview advanced encryption'
    'INFORMATION_BARRIERS' = 'Information barriers'
    'RECORDS_MANAGEMENT'   = 'Purview records management'
    'INSIDER_RISK'     = 'Insider Risk Management                                   [SC-200/400]'
    'EQUIVIO_ANALYTICS'= 'eDiscovery Premium'
    'LOCKBOX_ENTERPRISE' = 'Customer Lockbox'
    'MIP_S_CLP1'       = 'Sensitivity labels / auto-labelling'
}

Write-Host "=== 2. Security service plans - PROVISIONED? ==============" -ForegroundColor Cyan
Write-Host "    (a trial can land with plans PendingProvisioning for hours)" -ForegroundColor DarkGray

$planRows = foreach ($sku in $skus) {
    foreach ($p in $sku.ServicePlans) {
        foreach ($k in $gates.Keys) {
            if ($p.ServicePlanName -like "$k*") {
                [pscustomobject]@{
                    Sku      = $sku.SkuPartNumber
                    Plan     = $p.ServicePlanName
                    Status   = $p.ProvisioningStatus
                    Capability = $gates[$k]
                }
                break
            }
        }
    }
}

if ($planRows) {
    $planRows | Sort-Object Status, Capability | Format-Table Status, Plan, Capability -AutoSize
    $pending = @($planRows | Where-Object Status -ne 'Success')
    if ($pending.Count) {
        Write-Host "  [WARN] $($pending.Count) plan(s) not yet 'Success'. Re-run in an hour before concluding anything." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK  ] All matched security plans report Success." -ForegroundColor Green
    }
} else {
    Write-Host "  [WARN] No matching security service plans found." -ForegroundColor Yellow
}
Write-Host ""

# --- 3. Assignment - the step people skip -------------------------------------
Write-Host "=== 3. Who is actually LICENSED ===========================" -ForegroundColor Cyan
Write-Host "    A licence in the tenant does nothing until it is assigned to a user." -ForegroundColor DarkGray

$users = Get-MgUser -All -Property Id,UserPrincipalName,DisplayName,AssignedLicenses,AccountEnabled,UserType
$licensed   = @($users | Where-Object { $_.AssignedLicenses.Count -gt 0 })
$unlicensed = @($users | Where-Object { $_.AssignedLicenses.Count -eq 0 -and $_.UserType -ne 'Guest' })

Write-Host ("  Users: {0}   Licensed: {1}   Unlicensed (member): {2}" -f `
    @($users).Count, $licensed.Count, $unlicensed.Count)

if ($licensed.Count -eq 0 -and @($skus | Where-Object { $_.PrepaidUnits.Enabled -gt 0 }).Count -gt 0) {
    Write-Host "  [STOP] ⭐ Seats are OWNED but ZERO are ASSIGNED. Nothing is licensed." -ForegroundColor Red
    Write-Host "         Every P2/Defender/Intune feature is inert until a seat lands on a user." -ForegroundColor Red
    Write-Host "         This is licensing-and-service-limits sec.1 - the gate is SILENT." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "         Fix (UsageLocation FIRST - assignment fails without it):" -ForegroundColor Yellow
    Write-Host '           Update-MgUser -UserId <upn> -UsageLocation CA' -ForegroundColor Gray
    Write-Host '           $sku = (Get-MgSubscribedSku | ? SkuPartNumber -eq "SPE_E5").SkuId' -ForegroundColor Gray
    Write-Host '           Set-MgUserLicense -UserId <upn> -AddLicenses @{SkuId=$sku} -RemoveLicenses @()' -ForegroundColor Gray
    Write-Host ""
}
elseif ($unlicensed.Count) {
    Write-Host "  [WARN] Unlicensed members - P2 features will NOT apply to these accounts:" -ForegroundColor Yellow
    $unlicensed | Select-Object -First 15 UserPrincipalName, AccountEnabled | Format-Table -AutoSize
}
Write-Host ""

# --- 4. Trial clock ------------------------------------------------------------
Write-Host "=== 4. The clock ==========================================" -ForegroundColor Cyan
$expiry = Get-Date '2026-09-10'
$daysLeft = [int]($expiry - (Get-Date)).TotalDays
Write-Host ("  M365 E5 trial expires {0:yyyy-MM-dd} - {1} day(s) remaining." -f $expiry, $daysLeft) `
    -ForegroundColor $(if ($daysLeft -le 7) { 'Red' } elseif ($daysLeft -le 14) { 'Yellow' } else { 'Green' })
Write-Host "  Set a cancellation reminder for $(($expiry.AddDays(-5)).ToString('yyyy-MM-dd')) or it converts to paid." -ForegroundColor DarkGray
Write-Host ""

# --- 5. What is STILL blocked --------------------------------------------------
Write-Host "=== 5. Still blocked ======================================" -ForegroundColor Cyan
$azConnected = $false
$azSubs = @()
try {
    $azAccount = az account list --only-show-errors 2>$null | ConvertFrom-Json
    # ⭐ BUG FIX: `az account list` returns a TENANT-LEVEL placeholder entry even when the
    #    account has no subscription at all - it appears as name 'N/A(tenant level account)'
    #    with a tenantId as its id. Counting rows therefore reports a subscription that does
    #    not exist, which would wrongly unblock every Sentinel/Defender-for-Cloud lab.
    #    Filter to entries that are actually subscriptions.
    $azSubs = @($azAccount | Where-Object {
        $_.name -ne 'N/A(tenant level account)' -and $_.id -ne $_.tenantId
    })
    $azConnected = $azSubs.Count -gt 0
} catch { $azConnected = $false }
$azAccount = $azSubs

if ($azConnected) {
    Write-Host "  [OK  ] Azure subscription(s) present:" -ForegroundColor Green
    $azAccount | Select-Object name, id, state | Format-Table -AutoSize
} else {
    Write-Host "  [BLOCKED] No Azure subscription. E5 buys the M365/Entra/Defender-XDR half only." -ForegroundColor Red
    Write-Host "            Unrunnable without one:" -ForegroundColor Red
    @(
        'Microsoft Sentinel (needs a Log Analytics workspace)'
        'Defender for Cloud, attack path analysis, posture management'
        'Azure Policy, resource locks, landing zones, budgets'
        'Key Vault, managed identities against Azure resources, private endpoints'
        'Bicep / Terraform labs'
        'All of 60-ai-and-secure-ai (Foundry, AI Search, Content Safety)'
    ) | ForEach-Object { Write-Host "              - $_" -ForegroundColor DarkGray }
    Write-Host "            Fix: Azure free account (`$200 / 30 days). Running both clocks together" -ForegroundColor Yellow
    Write-Host "            is the ONLY window for Sentinel + Defender XDR integration labs." -ForegroundColor Yellow
}
Write-Host ""

# --- Output --------------------------------------------------------------------
$report = [ordered]@{
    checkedUtc     = (Get-Date).ToUniversalTime().ToString('o')
    tenant         = $org.DisplayName
    tenantId       = $org.Id
    skus           = @($skuRows)
    servicePlans   = @($planRows)
    userCount      = @($users).Count
    licensedCount  = $licensed.Count
    unlicensedUpns = @($unlicensed.UserPrincipalName)
    trialExpires   = $expiry.ToString('yyyy-MM-dd')
    daysRemaining  = $daysLeft
    azureSubscription = $azConnected
}

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8
    Write-Host "Evidence written: $OutFile" -ForegroundColor Green
    Write-Host "  -> commit this. It is the 'before' state, and the trial expires." -ForegroundColor DarkGray
}

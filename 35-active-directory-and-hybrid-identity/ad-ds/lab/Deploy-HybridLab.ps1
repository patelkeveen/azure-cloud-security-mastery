<#
.SYNOPSIS
    Deploys the hybrid identity lab (1 DC + 1 sync server) and manages its lifecycle.

.DESCRIPTION
    Dry-run by default, like every other script in this repo. Nothing is created
    until you pass -Apply.

    It checks the things that actually fail before it spends any of your credit:
      * vCPU quota    - Free Trial subscriptions CANNOT request an increase.
                        Discovering this after a failed deployment wastes an hour.
      * your public IP - the NSG is locked to it. ISPs rotate it; re-run -SetMyIp.
      * credit         - prints projected burn against what you actually have.

.PARAMETER Apply
    Actually deploy. Without it you get a what-if plan.

.PARAMETER SetDnsToDC
    Post-promotion step. Points the VNet's DNS at the DC and restarts sync01 so
    it picks up the new resolver. Run this ONLY after the forest is promoted.

.PARAMETER SetMyIp
    Re-detect your public IP and update the NSG rule. Run when RDP stops working.

.PARAMETER Stop
    Deallocate both VMs now. Deallocated = compute billing stops.

.PARAMETER Start
    Start both VMs.

.PARAMETER Destroy
    Delete the whole resource group. Prompts unless you also pass -Force.

.EXAMPLE
    .\Deploy-HybridLab.ps1                      # plan only
    .\Deploy-HybridLab.ps1 -Apply               # build it
    .\Deploy-HybridLab.ps1 -SetDnsToDC -Apply   # after promoting the forest
    .\Deploy-HybridLab.ps1 -Stop                # end of day
    .\Deploy-HybridLab.ps1 -Destroy -Apply      # when you are done
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$SetDnsToDC,
    [switch]$SetMyIp,
    [switch]$Stop,
    [switch]$Start,
    [switch]$Destroy,
    [switch]$Force,
    [string]$ResourceGroup = 'sc-300-lab-cin-rg-01',
    [string]$Location      = 'centralindia',
    [string]$Prefix        = 'sc300lab',
    [string]$VmSize        = 'Standard_B2s',
    [int]   $CreditInr     = 19130,
    [string]$CreditExpiry  = '2026-09-10'
)

$ErrorActionPreference = 'Stop'
$bicep = Join-Path $PSScriptRoot 'hybrid-lab.bicep'

function Say  { param($m,$c='Gray')    Write-Host "  $m" -ForegroundColor $c }
function Head { param($m) Write-Host "`n=== $m " -ForegroundColor Cyan -NoNewline; Write-Host ('=' * [Math]::Max(0, 58 - $m.Length)) -ForegroundColor Cyan }
function Ok   { param($m)              Write-Host "  [OK  ] $m" -ForegroundColor Green }
function Warn { param($m)              Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Bad  { param($m)              Write-Host "  [FAIL] $m" -ForegroundColor Red }

# -----------------------------------------------------------------------------
# 0. Context
# -----------------------------------------------------------------------------
Head 'Context'
try { $acct = az account show --output json 2>$null | ConvertFrom-Json } catch { $acct = $null }
if (-not $acct) { Bad 'Not signed in. Run: az login'; exit 1 }
Say "Subscription : $($acct.name)  ($($acct.id))"
Say "Tenant       : $($acct.tenantDefaultDomain)"
Say "Mode         : $(if($Apply){'APPLY'}else{'DRY RUN - pass -Apply to execute'})" $(if($Apply){'Yellow'}else{'DarkGray'})

$daysLeft = ([datetime]$CreditExpiry - (Get-Date)).Days
Say "Credit       : INR $CreditInr, expires $CreditExpiry ($daysLeft days)" 'Yellow'

# -----------------------------------------------------------------------------
# Lifecycle shortcuts - handled before the deploy path
# -----------------------------------------------------------------------------
if ($Stop -or $Start) {
    $action = if ($Stop) { 'deallocate' } else { 'start' }
    Head ("VM $action")
    foreach ($vm in @("$Prefix-dc01","$Prefix-sync01")) {
        if ($Apply -or $Stop) {
            az vm $action --resource-group $ResourceGroup --name $vm --no-wait 2>$null | Out-Null
            Ok "$action requested: $vm"
        } else { Say "[DRYRUN] $action $vm" }
    }
    if ($Stop) { Say 'Deallocated VMs bill disk only (~INR 25/day each). Compute stops.' 'DarkGray' }
    exit 0
}

if ($Destroy) {
    Head 'DESTROY'
    Warn "This deletes the ENTIRE resource group '$ResourceGroup' and everything in it."
    if (-not $Apply) { Say '[DRYRUN] Nothing deleted. Add -Apply to proceed.'; exit 0 }
    if (-not $Force) {
        $c = Read-Host "Type the resource group name to confirm"
        if ($c -ne $ResourceGroup) { Bad 'Mismatch. Aborted.'; exit 1 }
    }
    az group delete --name $ResourceGroup --yes --no-wait
    Ok 'Delete requested (async).'
    exit 0
}

# -----------------------------------------------------------------------------
# 1. Public IP detection - the NSG depends on this being right
# -----------------------------------------------------------------------------
Head 'Your public IP (the NSG allow-list)'
$myIp = $null
foreach ($svc in 'https://api.ipify.org','https://ifconfig.me/ip','https://icanhazip.com') {
    try { $myIp = (Invoke-RestMethod -Uri $svc -TimeoutSec 10).ToString().Trim(); if ($myIp) { break } } catch { }
}
if (-not $myIp -or $myIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { Bad 'Could not determine your public IP.'; exit 1 }
$myCidr = "$myIp/32"
Ok "Detected $myCidr"
Say 'RDP will be allowed from this address ONLY. If your ISP rotates it, re-run with -SetMyIp -Apply.' 'DarkGray'

if ($SetMyIp) {
    Head 'Update NSG source IP'
    if ($Apply) {
        az network nsg rule update --resource-group $ResourceGroup --nsg-name "$Prefix-nsg" `
            --name 'Allow-RDP-From-My-IP-Only' --source-address-prefixes $myCidr --output none
        Ok "NSG rule now allows $myCidr"
    } else { Say "[DRYRUN] would set NSG source to $myCidr" }
    exit 0
}

# -----------------------------------------------------------------------------
# 2. Post-promotion DNS switch
#    This is the step everyone forgets, and the symptom is "sync01 cannot join
#    the domain" - because it is still asking Azure's resolver about a zone only
#    the DC knows.
# -----------------------------------------------------------------------------
if ($SetDnsToDC) {
    Head 'Point VNet DNS at the domain controller'
    $dcIp = az vm show -g $ResourceGroup -n "$Prefix-dc01" -d --query privateIps -o tsv 2>$null
    if (-not $dcIp) { Bad "Could not read dc01's private IP. Is it deployed and running?"; exit 1 }
    Say "DC private IP: $dcIp"
    Say 'Order matters: promote the forest FIRST, then run this. Doing it early leaves' 'DarkGray'
    Say 'sync01 with a resolver that is not answering yet, and nothing installs.' 'DarkGray'
    if ($Apply) {
        az network vnet update -g $ResourceGroup -n "$Prefix-vnet" --dns-servers $dcIp --output none
        Ok "VNet DNS -> $dcIp"
        az vm restart -g $ResourceGroup -n "$Prefix-sync01" --no-wait 2>$null | Out-Null
        Ok 'sync01 restarting to pick up the new resolver.'
        Say 'A DHCP lease renew is what actually applies it. A restart is the blunt, reliable way.' 'DarkGray'
    } else { Say "[DRYRUN] would set VNet DNS to $dcIp and restart sync01" }
    exit 0
}

# -----------------------------------------------------------------------------
# 3. Quota - fail fast. This is the constraint, not money.
# -----------------------------------------------------------------------------
Head 'vCPU quota check'
$needed = 4   # 2 VMs x 2 vCPU
$usage = az vm list-usage --location $Location --output json 2>$null | ConvertFrom-Json
$regional = $usage | Where-Object { $_.name.value -eq 'cores' }
$bfamily  = $usage | Where-Object { $_.name.value -match 'standardBSFamily' }

$blocked = $false
foreach ($q in @($regional, $bfamily)) {
    if (-not $q) { continue }
    $free = $q.limit - $q.currentValue
    $line = "{0,-34} used {1,3} / {2,3}  (free {3})" -f $q.localName, $q.currentValue, $q.limit, $free
    if ($free -lt $needed) { Bad $line; $blocked = $true } else { Ok $line }
}
if (-not $regional -and -not $bfamily) { Warn 'Could not read quota. Continuing, but a deploy may fail on cores.' }

if ($blocked) {
    Bad "This lab needs $needed vCPU and you do not have that much headroom."
    Say ''
    Say 'Free Trial subscriptions CANNOT request a quota increase. Options:' 'Yellow'
    Say '  a) Deploy ONE VM (the DC) and install Entra Connect on it.' 'White'
    Say '     Not production shape - you would separate them - but it labs fine.' 'DarkGray'
    Say '  b) Upgrade to Pay-As-You-Go. Your credit carries over and the quota lifts.' 'White'
    Say '  c) Use Standard_B1ms (1 vCPU) - too small for Entra Connect + SQL Express.' 'DarkGray'
    if (-not $Force) { exit 1 }
}

# -----------------------------------------------------------------------------
# 4. Cost projection from LIVE retail prices, not a guess
# -----------------------------------------------------------------------------
Head 'Cost projection (live retail API, INR)'
try {
    $f = "armRegionName eq '$Location' and serviceName eq 'Virtual Machines' and priceType eq 'Consumption' and armSkuName eq '$VmSize'"
    $uri = 'https://prices.azure.com/api/retail/prices?currencyCode=%27INR%27&$filter=' + [uri]::EscapeDataString($f)
    $items = (Invoke-RestMethod -Uri $uri -TimeoutSec 30).Items
    $hr = ($items | Where-Object { $_.productName -match 'Windows' -and $_.skuName -notmatch 'Spot|Low Priority' } |
           Select-Object -First 1).retailPrice
    if ($hr) {
        $d24 = [math]::Round($hr * 24 * 2 * $daysLeft)
        $d8  = [math]::Round($hr * 8  * 2 * $daysLeft)
        Say ("{0} Windows: INR {1}/hr each" -f $VmSize, $hr)
        Say ("2 VMs, 24/7, {0} days : INR {1,6:N0}   ({2:P0} of credit)" -f $daysLeft, $d24, ($d24/$CreditInr)) 'White'
        Say ("2 VMs, 8h/day, {0} days: INR {1,6:N0}   ({2:P0} of credit)" -f $daysLeft, $d8,  ($d8/$CreditInr)) 'White'
        Say '+ ~INR 50/day for two StandardSSD OS disks, which bill even when deallocated.' 'DarkGray'
        Ok 'Money is not your constraint here. Do not over-optimise it.'
    }
} catch { Warn "Price API unavailable: $($_.Exception.Message)" }

# -----------------------------------------------------------------------------
# 5. Deploy
# -----------------------------------------------------------------------------
Head 'Deploy'
if (-not (Test-Path $bicep)) { Bad "Template not found: $bicep"; exit 1 }

az group create --name $ResourceGroup --location $Location `
    --tags owner=keveen environment=lab expires=$CreditExpiry costCenter=personal purpose=sc300-hybrid `
    --output none
Ok "Resource group ready: $ResourceGroup"

if (-not $env:LAB_ADMIN_PASSWORD) {
    Warn 'Set $env:LAB_ADMIN_PASSWORD before -Apply. Passwords do not belong in command history.'
    Say '  $env:LAB_ADMIN_PASSWORD = Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText' 'DarkGray'
    if ($Apply) { exit 1 }
}

$deployArgs = @(
    'deployment','group', $(if ($Apply) { 'create' } else { 'what-if' }),
    '--resource-group', $ResourceGroup,
    '--template-file', $bicep,
    '--parameters', "allowedSourceIp=$myCidr", "vmSize=$VmSize", "prefix=$Prefix",
                    "expiresTag=$CreditExpiry", "adminPassword=$env:LAB_ADMIN_PASSWORD"
)
if ($Apply) { $deployArgs += @('--name', "hybridlab-$(Get-Date -f 'yyyyMMdd-HHmm')", '--output','json') }

az @deployArgs | Tee-Object -Variable raw | Out-Null
if ($LASTEXITCODE -ne 0) { Bad 'Deployment failed. Read the error above.'; exit 1 }

if (-not $Apply) {
    az @deployArgs
    Say ''
    Ok 'What-if complete. Nothing was created. Re-run with -Apply.'
    exit 0
}

$out = ($raw | ConvertFrom-Json).properties.outputs
Ok 'Deployed.'
Say ''
Say "  sync01 (jump host) : $($out.syncPublicFqdn.value)" 'White'
Say "  dc01   (private)   : $($out.dcPrivateIp.value)   <- no public IP, by design" 'White'
Say ''

Head 'Next, in order - the order is the lesson'
@(
 '1. RDP to sync01 using the FQDN above.'
 '2. From sync01, RDP to 10.50.1.4 (dc01). It has no public IP - this is the jump-host pattern.'
 '3. ON dc01: run Initialize-LabForest.ps1 -Apply. It promotes the forest and seeds AD.'
 '   The VM reboots. That is expected.'
 '4. BACK HERE: .\Deploy-HybridLab.ps1 -SetDnsToDC -Apply'
 '   <- Skipping this is why "sync01 cannot join the domain" happens.'
 '5. Join sync01 to the domain, then install Entra Connect on sync01.'
 '6. End of day: .\Deploy-HybridLab.ps1 -Stop'
) | ForEach-Object { Say $_ 'White' }
Say ''
Warn "Everything is tagged expires=$CreditExpiry. Delete it with -Destroy -Apply when done."

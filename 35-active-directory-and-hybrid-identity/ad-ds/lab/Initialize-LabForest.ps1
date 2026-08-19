<#
.SYNOPSIS
    Runs ON dc01. Promotes the forest, then seeds AD so that Entra Connect has
    something worth syncing - including the failures worth causing.

.DESCRIPTION
    Two phases, because a forest promotion reboots the machine.

      -Promote   installs AD DS + DNS, creates the forest, reboots.
      -Seed      (after reboot) adds the routable UPN suffix, the OU structure,
                 and users deliberately designed to exercise matching.

    THE ONE THING THIS LAB IS REALLY ABOUT
    --------------------------------------
    The forest is kwinlab.local - deliberately non-routable, because that is what
    you will actually walk into at a customer. A .local UPN CANNOT sync usefully:
    Entra rejects the suffix and stamps every user @<tenant>.onmicrosoft.com, so
    nobody can sign in with the username they already know.

    The fix is not to rename the forest. It is to add a VERIFIED, ROUTABLE domain
    as an alternative UPN suffix and restamp user UPNs onto it. That single step
    is the most common hybrid identity remediation in the field, and it is why
    "we'll just install Connect on Friday" goes wrong.

.PARAMETER DomainName
    AD forest FQDN. Default kwinlab.local - non-routable ON PURPOSE.

.PARAMETER RoutableSuffix
    A domain VERIFIED IN YOUR TENANT. Users get UPNs on this. Default KWin.onmicrosoft.com.

.EXAMPLE
    .\Initialize-LabForest.ps1 -Promote -Apply     # phase 1, reboots
    .\Initialize-LabForest.ps1 -Seed -Apply        # phase 2, after reboot
#>
[CmdletBinding()]
param(
    [switch]$Promote,
    [switch]$Seed,
    [switch]$Apply,
    [string]$DomainName     = 'kwinlab.local',
    [string]$NetbiosName    = 'KWINLAB',
    [string]$RoutableSuffix = 'KWin.onmicrosoft.com'
)

$ErrorActionPreference = 'Stop'
function Head { param($m) Write-Host "`n=== $m " -ForegroundColor Cyan -NoNewline; Write-Host ('=' * [Math]::Max(0, 58 - $m.Length)) -ForegroundColor Cyan }
function Say  { param($m,$c='Gray') Write-Host "  $m" -ForegroundColor $c }
function Ok   { param($m) Write-Host "  [OK  ] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Do-It { param($what,[scriptblock]$act)
    if ($Apply) { try { & $act; Ok $what } catch { Write-Host "  [FAIL] $what -> $($_.Exception.Message)" -ForegroundColor Red } }
    else { Say "[DRYRUN] $what" 'DarkGray' }
}

if (-not $Promote -and -not $Seed) {
    Write-Host @'

  Pick a phase:
    -Promote   install AD DS, create the forest, reboot   (run first)
    -Seed      add UPN suffix, OUs and users              (run after reboot)

  Both are dry-run unless you add -Apply.

'@ -ForegroundColor Yellow
    exit 0
}

Say "Mode: $(if($Apply){'APPLY'}else{'DRY RUN'})" $(if($Apply){'Yellow'}else{'DarkGray'})

# =============================================================================
# PHASE 1 - PROMOTE
# =============================================================================
if ($Promote) {
    Head 'Phase 1 - promote the forest'

    Say 'Sanity checks first. A DC with the wrong network config is a bad afternoon.' 'DarkGray'
    $ip = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }).IPv4Address.IPAddress
    Say "This machine's IP: $ip"
    if ($ip -ne '10.50.1.4') { Warn "Expected 10.50.1.4 from the Bicep template. Got $ip. Check you are on dc01." }

    Say ''
    Say 'NOTE - do NOT set a static IP inside Windows on an Azure VM.' 'Yellow'
    Say 'Azure hands out this address by DHCP with an infinite lease and the NIC is' 'DarkGray'
    Say 'marked Static at the platform layer. Hard-coding it in the guest is a' 'DarkGray'
    Say 'classic way to lose all connectivity to a cloud DC.' 'DarkGray'

    Do-It 'Install AD-Domain-Services + management tools' {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
    }

    Say ''
    Say 'Now the promotion. You will be prompted for the DSRM password.' 'White'
    Say 'DSRM = Directory Services Restore Mode - a separate local admin credential' 'DarkGray'
    Say 'used only when the DC boots without AD. Store it where you store break-glass;' 'DarkGray'
    Say 'needing it and not having it is an unrecoverable-DC scenario.' 'DarkGray'

    Do-It "Create forest $DomainName (NetBIOS $NetbiosName) - REBOOTS" {
        Import-Module ADDSDeployment
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $NetbiosName `
            -InstallDns:$true `
            -DomainMode 'WinThreshold' `
            -ForestMode 'WinThreshold' `
            -NoRebootOnCompletion:$false `
            -Force:$true
    }

    if (-not $Apply) {
        Say ''
        Say 'After the reboot:' 'White'
        Say '  1. On your laptop:  .\Deploy-HybridLab.ps1 -SetDnsToDC -Apply' 'White'
        Say '  2. Back on dc01  :  .\Initialize-LabForest.ps1 -Seed -Apply' 'White'
    }
    return
}

# =============================================================================
# PHASE 2 - SEED
# =============================================================================
Head 'Phase 2 - make the directory worth syncing'

try { Import-Module ActiveDirectory -ErrorAction Stop } catch { Warn 'ActiveDirectory module missing - is the forest promoted?'; exit 1 }

# --- 2.1 The routable UPN suffix - the whole point of the lab -----------------
Head '2.1 Alternative UPN suffix'
Say "Adding '$RoutableSuffix' as a UPN suffix on the forest." 'White'
Say 'Without this, every user is someone@kwinlab.local, Entra will not accept that' 'DarkGray'
Say 'suffix, and Connect stamps them @<tenant>.onmicrosoft.com instead. Users then' 'DarkGray'
Say 'cannot sign in with the name they already know, and the helpdesk drowns.' 'DarkGray'

Do-It "Add UPN suffix $RoutableSuffix" {
    Set-ADForest -Identity (Get-ADForest).Name -UPNSuffixes @{Add=$RoutableSuffix}
}

# --- 2.2 OU structure ---------------------------------------------------------
Head '2.2 OU structure'
Say 'Flat directories cannot be filtered. Connect scopes sync BY OU, so the OU' 'DarkGray'
Say 'design decides what is syncable - it is an identity decision, not tidiness.' 'DarkGray'

$root = (Get-ADDomain).DistinguishedName
$corpDn = "OU=Corp,$root"

Do-It 'Create OU=Corp' { New-ADOrganizationalUnit -Name 'Corp' -Path $root -ProtectedFromAccidentalDeletion $true }
foreach ($d in 'Finance','Engineering','Sales','HumanResources') {
    Do-It "Create OU=$d under Corp" { New-ADOrganizationalUnit -Name $d -Path $corpDn -ProtectedFromAccidentalDeletion $true }
}
Do-It 'Create OU=ServiceAccounts' { New-ADOrganizationalUnit -Name 'ServiceAccounts' -Path $root -ProtectedFromAccidentalDeletion $true }
Do-It 'Create OU=NoSync  (proves OU filtering works)' { New-ADOrganizationalUnit -Name 'NoSync' -Path $root -ProtectedFromAccidentalDeletion $true }

# --- 2.3 Users that mirror the Entra tenant ----------------------------------
# These UPNs deliberately MATCH Seed-LabTenant.ps1's cloud users so that Entra
# Connect SOFT MATCHES them: primary SMTP / UPN equality joins an on-prem object
# to an existing cloud object instead of creating a duplicate.
Head '2.3 Users - built for soft match'
Say 'SOFT MATCH  joins on UPN or primary SMTP. No admin action needed.' 'White'
Say 'HARD MATCH  joins on immutableId / sourceAnchor - you set it deliberately.' 'White'
Say ''
Say 'Since 2026-07-01 hard match is BLOCKED against cloud accounts that hold, or' 'Yellow'
Say 'are eligible for, a privileged role, or that already carry' 'Yellow'
Say 'onPremisesObjectIdentifier. Enforced cloud-side. Test it in sec.2.5.' 'Yellow'

$people = @(
    @{ First='Amara';  Last='Okonkwo';   OU='Finance';        Title='CFO' }
    @{ First='Diego';  Last='Ramirez';   OU='Finance';        Title='Financial Analyst' }
    @{ First='Wei';    Last='Zhang';     OU='Finance';        Title='Accountant' }
    @{ First='Tomas';  Last='Novak';     OU='Engineering';    Title='VP Engineering' }
    @{ First='Fatima'; Last='Al-Rashid'; OU='Engineering';    Title='Staff Engineer' }
    @{ First='Kwame';  Last='Mensah';    OU='Engineering';    Title='Senior Engineer' }
    @{ First='Elena';  Last='Petrova';   OU='Sales';          Title='VP Sales' }
    @{ First='Marcus'; Last='Bell';      OU='Sales';          Title='Account Executive' }
    @{ First='Ingrid'; Last='Larsen';    OU='HumanResources'; Title='CHRO' }
)

$pw = ConvertTo-SecureString 'LabP@ssw0rd!2026' -AsPlainText -Force
foreach ($p in $people) {
    $sam = "$($p.First).$($p.Last)".ToLower() -replace '[^a-z0-9.]',''
    if ($sam.Length -gt 20) { $sam = $sam.Substring(0,20) }   # sAMAccountName is capped at 20 chars
    $upn = "$($p.First).$($p.Last)@$RoutableSuffix".ToLower()
    Do-It "User $upn -> OU=$($p.OU)" {
        New-ADUser -Name "$($p.First) $($p.Last)" -GivenName $p.First -Surname $p.Last `
            -SamAccountName $sam -UserPrincipalName $upn `
            -Path "OU=$($p.OU),$corpDn" -Title $p.Title -Department $p.OU `
            -EmailAddress $upn -AccountPassword $pw -Enabled $true `
            -ChangePasswordAtLogon $false
    }
}
Say ''
Say 'sAMAccountName is capped at 20 characters. "fatima.al-rashid" is 16 - fine.' 'DarkGray'
Say 'Longer names silently truncate and then collide. Real migrations die on this.' 'DarkGray'

# --- 2.4 The objects that exist to FAIL ---------------------------------------
Head '2.4 Deliberate failure cases'
Say 'A lab that only succeeds teaches you nothing you can use at 2am.' 'White'

Do-It 'NoSync user  (proves OU filtering excludes it)' {
    New-ADUser -Name 'Excluded User' -GivenName 'Excluded' -Surname 'User' `
        -SamAccountName 'excluded.user' -UserPrincipalName "excluded.user@$RoutableSuffix" `
        -Path "OU=NoSync,$root" -AccountPassword $pw -Enabled $true
}

Do-It 'Non-routable UPN user  (watch Entra restamp this one)' {
    New-ADUser -Name 'Legacy Local' -GivenName 'Legacy' -Surname 'Local' `
        -SamAccountName 'legacy.local' -UserPrincipalName "legacy.local@$DomainName" `
        -Path "OU=Corp,$root" -AccountPassword $pw -Enabled $true
}

Do-It 'Duplicate proxyAddress  (causes a real sync error)' {
    New-ADUser -Name 'Dupe Address' -GivenName 'Dupe' -Surname 'Address' `
        -SamAccountName 'dupe.address' -UserPrincipalName "dupe.address@$RoutableSuffix" `
        -Path "OU=Corp,$root" -AccountPassword $pw -Enabled $true `
        -OtherAttributes @{ proxyAddresses = "SMTP:amara.okonkwo@$RoutableSuffix" }
}

Do-It 'Sync service account in OU=ServiceAccounts' {
    New-ADUser -Name 'svc-entraconnect' -SamAccountName 'svc-entraconnect' `
        -UserPrincipalName "svc-entraconnect@$RoutableSuffix" `
        -Path "OU=ServiceAccounts,$root" -AccountPassword $pw -Enabled $true `
        -PasswordNeverExpires $true `
        -Description 'Entra Connect AD DS connector account. Least privilege - NOT Domain Admin.'
}

Say ''
Say 'The duplicate proxyAddress is the single most common Entra Connect error in' 'Yellow'
Say 'production. It surfaces as an export error, not an import one, so people look' 'Yellow'
Say 'in the wrong place. You will see it in Synchronization Service Manager as' 'Yellow'
Say 'AttributeValueMustBeUnique. Capture that string verbatim.' 'Yellow'

# --- 2.5 What to do next ------------------------------------------------------
Head 'Next'
@(
 '1. On your laptop, if you have not already:'
 '     .\Deploy-HybridLab.ps1 -SetDnsToDC -Apply'
 '2. Join sync01 to the domain, reboot it.'
 '3. Install Entra Connect ON SYNC01 (never on the DC in production - it needs'
 '   SQL, patching and reboots on a different cadence to a DC).'
 '4. Choose Password Hash Synchronisation. Scope sync to OU=Corp only.'
 '5. Watch: Excluded User must NOT appear in Entra. Legacy Local MUST appear'
 '   with a restamped @onmicrosoft.com UPN. Dupe Address MUST error.'
 '6. Log every error verbatim - that is the artifact you cannot recreate later.'
) | ForEach-Object { Say $_ 'White' }
Say ''
Say 'Reference: ../../entra-connect-sync/README.md and ../../source-anchor-and-matching/' 'DarkGray'

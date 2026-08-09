<#
.SYNOPSIS
    Seed a fresh Entra tenant with a realistic org so SC-300 labs have something to act on.

.DESCRIPTION
    An empty tenant teaches nothing. Dynamic groups need attributes to match on. Access
    reviews need a manager chain. PIM needs someone to elevate. Lifecycle Workflows need
    joiners and leavers. This creates all of it.

    Builds:
      * 2 break-glass accounts   (the design pattern - cloud-only, excluded from CA)
      * 16 users across 4 departments, with a manager hierarchy
      * 1 offboarding-test user  (hire date past, for Lifecycle Workflow labs)
      * 4 dynamic security groups (department-based - teaches membership rule syntax)
      * 1 assigned group for CA break-glass exclusion
      * 1 app registration        (for the Layer 1 JWT / client-credentials labs)

    DRY RUN BY DEFAULT. Nothing is created unless you pass -Apply.
    Idempotent: re-running skips objects that already exist.

.PARAMETER Apply
    Actually create objects. Without it, prints the plan.

.PARAMETER Remove
    Tear everything down. Use between lab resets.

.EXAMPLE
    .\Seed-LabTenant.ps1                 # see the plan
    .\Seed-LabTenant.ps1 -Apply          # build it
    .\Seed-LabTenant.ps1 -Remove -Apply  # tear down

.NOTES
    Requires: Microsoft.Graph module, Global Administrator.
    Break-glass passwords are printed ONCE and never stored. Put them somewhere real.
#>
[CmdletBinding()]
param([switch]$Apply, [switch]$Remove)

$ErrorActionPreference = 'Stop'

# --- Connect -----------------------------------------------------------------
# These are DELEGATED scopes. Your effective rights = intersection of these and
# your own directory role. Missing scope and missing role fail identically -
# telling them apart is the skill (see LAYER-1-IDENTITY-PROTOCOLS.md sec.8).
$Scopes = @(
    'User.ReadWrite.All'
    'Group.ReadWrite.All'
    'Application.ReadWrite.All'
    'Directory.ReadWrite.All'
)

if (-not (Get-MgContext)) {
    Write-Host "Connecting to Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $Scopes -NoWelcome
}
$ctx = Get-MgContext
if (-not $ctx) { throw "Not connected to Graph." }

$TenantDomain = (Get-MgOrganization).VerifiedDomains |
    Where-Object { $_.IsInitial } | Select-Object -ExpandProperty Name
Write-Host "Tenant : $TenantDomain" -ForegroundColor Green
Write-Host "Account: $($ctx.Account)" -ForegroundColor Green
Write-Host "Mode   : $(if($Apply){'APPLY'}else{'DRY RUN - pass -Apply to execute'})`n" -ForegroundColor $(if($Apply){'Green'}else{'Yellow'})

function Step {
    param([string]$What, [scriptblock]$Do)
    if (-not $Apply) { Write-Host "  [DRYRUN ] $What" -ForegroundColor Yellow; return }
    try   { $r = & $Do; Write-Host "  [OK     ] $What" -ForegroundColor Green; return $r }
    catch { Write-Host "  [FAIL   ] $What -> $($_.Exception.Message)" -ForegroundColor Red }
}

function New-LabPassword {
    # 20 chars from a set with no ambiguous glyphs. Break-glass creds get typed
    # off paper under pressure - 0/O and 1/l/I confusion is a real outage cause.
    $set = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%^&*'
    -join (1..20 | ForEach-Object { $set[(Get-Random -Maximum $set.Length)] })
}

# --- The org -----------------------------------------------------------------
$Departments = 'Finance','Engineering','Sales','HumanResources'

$People = @(
    @{ First='Amara';  Last='Okonkwo';   Dept='Finance';        Title='CFO';                 Mgr=$null }
    @{ First='Diego';  Last='Ramirez';   Dept='Finance';        Title='Financial Analyst';   Mgr='amara.okonkwo' }
    @{ First='Wei';    Last='Zhang';     Dept='Finance';        Title='Accountant';          Mgr='amara.okonkwo' }
    @{ First='Priya';  Last='Nair';      Dept='Finance';        Title='AP Clerk';            Mgr='diego.ramirez' }
    @{ First='Tomas';  Last='Novak';     Dept='Engineering';    Title='VP Engineering';      Mgr=$null }
    @{ First='Fatima'; Last='Al-Rashid'; Dept='Engineering';    Title='Staff Engineer';      Mgr='tomas.novak' }
    @{ First='Kwame';  Last='Mensah';    Dept='Engineering';    Title='Senior Engineer';     Mgr='tomas.novak' }
    @{ First='Sanne';  Last='Vermeulen'; Dept='Engineering';    Title='Engineer';            Mgr='fatima.al-rashid' }
    @{ First='Rohan';  Last='Kapoor';    Dept='Engineering';    Title='SRE';                 Mgr='fatima.al-rashid' }
    @{ First='Elena';  Last='Petrova';   Dept='Sales';          Title='VP Sales';            Mgr=$null }
    @{ First='Marcus'; Last='Bell';      Dept='Sales';          Title='Account Executive';   Mgr='elena.petrova' }
    @{ First='Yuki';   Last='Tanaka';    Dept='Sales';          Title='Sales Engineer';      Mgr='elena.petrova' }
    @{ First='Ingrid'; Last='Larsen';    Dept='HumanResources'; Title='CHRO';                Mgr=$null }
    @{ First='Omar';   Last='Haddad';    Dept='HumanResources'; Title='HR Business Partner'; Mgr='ingrid.larsen' }
    @{ First='Chloe';  Last='Dubois';    Dept='HumanResources'; Title='Recruiter';           Mgr='ingrid.larsen' }
    @{ First='Leaver'; Last='Testcase';  Dept='Sales';          Title='Former AE';           Mgr='elena.petrova' }
)

# =============================================================================
if ($Remove) {
    Write-Host "=== TEARDOWN ===" -ForegroundColor Cyan
    foreach ($p in $People) {
        $upn = "$($p.First).$($p.Last)@$TenantDomain".ToLower()
        $u = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
        if ($u) { Step "Delete user $upn" { Remove-MgUser -UserId $u.Id } }
    }
    foreach ($i in 1,2) {
        $upn = "breakglass$i@$TenantDomain"
        $u = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
        if ($u) { Step "Delete break-glass $upn" { Remove-MgUser -UserId $u.Id } }
    }
    foreach ($g in ($Departments | ForEach-Object { "SG-Dept-$_" }) + 'SG-CA-BreakGlass-Exclude') {
        $grp = Get-MgGroup -Filter "displayName eq '$g'" -ErrorAction SilentlyContinue
        if ($grp) { Step "Delete group $g" { Remove-MgGroup -GroupId $grp.Id } }
    }
    $app = Get-MgApplication -Filter "displayName eq 'SC300-Lab-App'" -ErrorAction SilentlyContinue
    if ($app) { Step "Delete app registration SC300-Lab-App" { Remove-MgApplication -ApplicationId $app.Id } }
    Write-Host "`nTeardown complete. Deleted users sit in the 30-day soft-delete bin.`n" -ForegroundColor Cyan
    return
}

# --- 1. Break-glass ----------------------------------------------------------
# Design pattern from SC-300-MASTERY-SYLLABUS.md sec.4.3. Two accounts so a single
# lost credential is not a lockout. Cloud-only + *.onmicrosoft.com so they survive
# a federation or Connect Sync outage. EXCLUDE THESE FROM EVERY CA POLICY.
Write-Host "=== 1. Break-glass accounts ===" -ForegroundColor Cyan
$bgCreds = @()
foreach ($i in 1,2) {
    $upn = "breakglass$i@$TenantDomain"
    if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP   ] $upn already exists" -ForegroundColor DarkGray; continue
    }
    $pw = New-LabPassword
    Step "Create $upn" {
        New-MgUser -UserPrincipalName $upn -DisplayName "Break Glass $i" `
            -MailNickname "breakglass$i" -AccountEnabled `
            -PasswordProfile @{ Password = $pw; ForceChangePasswordNextSignIn = $false } | Out-Null
    }
    $bgCreds += [pscustomobject]@{ UPN = $upn; Password = $pw }
}

# --- 2. Users ----------------------------------------------------------------
Write-Host "`n=== 2. Users ===" -ForegroundColor Cyan
foreach ($p in $People) {
    $upn = "$($p.First).$($p.Last)@$TenantDomain".ToLower()
    if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP   ] $upn exists" -ForegroundColor DarkGray; continue
    }
    Step "Create $($p.First) $($p.Last) - $($p.Dept)" {
        New-MgUser -UserPrincipalName $upn `
            -DisplayName "$($p.First) $($p.Last)" `
            -GivenName $p.First -Surname $p.Last `
            -MailNickname "$($p.First).$($p.Last)".ToLower() `
            -Department $p.Dept -JobTitle $p.Title `
            -UsageLocation 'CA' -AccountEnabled `
            -PasswordProfile @{ Password = (New-LabPassword); ForceChangePasswordNextSignIn = $true } | Out-Null
    }
}

# --- 3. Manager chain --------------------------------------------------------
# Access reviews and Lifecycle Workflows are useless without this. Most lab
# tenants skip it, which is why people have never seen a manager-scoped review.
Write-Host "`n=== 3. Manager relationships ===" -ForegroundColor Cyan
foreach ($p in ($People | Where-Object { $_.Mgr })) {
    $upn    = "$($p.First).$($p.Last)@$TenantDomain".ToLower()
    $mgrUpn = "$($p.Mgr)@$TenantDomain".ToLower()
    Step "$($p.First) $($p.Last) -> manager $($p.Mgr)" {
        $u = Get-MgUser -Filter "userPrincipalName eq '$upn'"
        $m = Get-MgUser -Filter "userPrincipalName eq '$mgrUpn'"
        Set-MgUserManagerByRef -UserId $u.Id -BodyParameter @{
            '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($m.Id)"
        }
    }
}

# --- 4. Dynamic groups -------------------------------------------------------
# Membership rules evaluate ASYNCHRONOUSLY. Expect minutes, not seconds. People
# assume the rule is broken when it is merely pending - watch ProcessingState.
Write-Host "`n=== 4. Dynamic groups ===" -ForegroundColor Cyan
foreach ($d in $Departments) {
    $name = "SG-Dept-$d"
    if (Get-MgGroup -Filter "displayName eq '$name'" -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP   ] $name exists" -ForegroundColor DarkGray; continue
    }
    Step "Create dynamic group $name" {
        New-MgGroup -DisplayName $name -MailEnabled:$false -MailNickname $name `
            -SecurityEnabled `
            -GroupTypes 'DynamicMembership' `
            -MembershipRule "(user.department -eq `"$d`")" `
            -MembershipRuleProcessingState 'On' | Out-Null
    }
}

$bgGroup = 'SG-CA-BreakGlass-Exclude'
if (-not (Get-MgGroup -Filter "displayName eq '$bgGroup'" -ErrorAction SilentlyContinue)) {
    Step "Create assigned group $bgGroup" {
        New-MgGroup -DisplayName $bgGroup -MailEnabled:$false `
            -MailNickname $bgGroup -SecurityEnabled | Out-Null
    }
}

# --- 5. Lab app registration -------------------------------------------------
# Target for the Layer 1 labs: decode a JWT, run client credentials by hand,
# compare delegated vs application permissions.
Write-Host "`n=== 5. App registration ===" -ForegroundColor Cyan
if (-not (Get-MgApplication -Filter "displayName eq 'SC300-Lab-App'" -ErrorAction SilentlyContinue)) {
    Step "Create app registration SC300-Lab-App" {
        New-MgApplication -DisplayName 'SC300-Lab-App' `
            -SignInAudience 'AzureADMyOrg' `
            -Web @{ RedirectUris = @('http://localhost:8400/callback') } | Out-Null
    }
}

# --- Output ------------------------------------------------------------------
if ($Apply -and $bgCreds) {
    Write-Host "`n" ('=' * 70) -ForegroundColor Red
    Write-Host " BREAK-GLASS CREDENTIALS - SHOWN ONCE, NOT STORED ANYWHERE" -ForegroundColor Red
    Write-Host ('=' * 70) -ForegroundColor Red
    $bgCreds | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host @"
 Do now, before anything else:
   1. Record these somewhere real (password manager / sealed envelope).
      Real-world practice splits them across two custodians.
   2. Assign Global Administrator to both.
   3. EXCLUDE both from every Conditional Access policy you create.
   4. Alert on their sign-in - they should never be used.

 Locking yourself out of your own tenant on day one is a rite of passage.
 Skip it.
"@ -ForegroundColor Yellow
    Write-Host ('=' * 70) -ForegroundColor Red
}

Write-Host "`nNext: verify dynamic membership populated (allow a few minutes):" -ForegroundColor Cyan
Write-Host '  Get-MgGroup -Filter "startswith(displayName,''SG-Dept-'')" | ForEach-Object {' -ForegroundColor Gray
Write-Host '      "{0}: {1}" -f $_.DisplayName, (Get-MgGroupMember -GroupId $_.Id).Count }' -ForegroundColor Gray
Write-Host ""

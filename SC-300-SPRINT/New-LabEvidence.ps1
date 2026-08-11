<#
.SYNOPSIS
    Capture lab output as durable evidence in a topic's facet folder - because the trial expires.

.DESCRIPTION
    ⭐ The trial is not 30 days of access. It is 30 days to produce artifacts that outlive it.

    On 2026-09-10 the M365 E5 licence lapses. What remains is whatever you wrote down. This
    script standardises that: it runs a command, captures the real output, and files it with a
    header stating what was run, when, against which tenant, and why it matters.

    It also moves the repo. COVERAGE.md classes a topic WRITTEN only when >=3 of 6 facets carry
    evidence; that count has been 0/144 for licensing reasons rather than effort. Every artifact
    filed here is a step from PARTIAL to WRITTEN.

    Facets (the repo's content contract):
      lab                    - it was built and it worked
      break-fix              - it was deliberately broken, and the failure was observed
      security               - the audit/finding output
      operations             - the runbook or register
      architecture-decisions - the ADR
      customer-use-cases     - the discovery questions answered

.PARAMETER Topic
    Repo-relative topic path, e.g. '30-identity-and-nhi/pim-and-access-reviews'.

.PARAMETER Facet
    Which facet folder to file under.

.PARAMETER Name
    Short kebab-case artifact name, e.g. 'pim-activation-proof'.

.PARAMETER Command
    Scriptblock to execute and capture. Its output becomes the artifact body.

.PARAMETER Note
    One line on WHY this is evidence - what claim it supports. Required: an artifact whose
    significance you cannot state in one line is a screenshot, not evidence.

.PARAMETER Redact
    Regex patterns to blank before writing. Defaults cover GUIDs-in-URLs and bearer tokens.

.EXAMPLE
    .\New-LabEvidence.ps1 -Topic 30-identity-and-nhi/pim-and-access-reviews `
        -Facet security -Name 'standing-owner-audit' `
        -Note 'Proves no standing Global Admin outside break-glass after PIM rollout' `
        -Command { Get-MgDirectoryRoleMember -DirectoryRoleId $gaId | Select DisplayName }

.NOTES
    Never captures secrets. If your command returns one, that is a finding about the command.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Topic,
    [Parameter(Mandatory)][ValidateSet('lab','break-fix','security','operations','architecture-decisions','customer-use-cases')]
    [string]$Facet,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Command,
    [Parameter(Mandatory)][string]$Note,
    [string[]]$Redact = @(
        '(?i)(bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*'
        '(?i)("?(password|secret|clientSecret|accessToken|refreshToken)"?\s*[:=]\s*)\S+'
    )
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

$topicPath = Join-Path $repo ($Topic -replace '/', '\')
if (-not (Test-Path $topicPath)) { throw "Topic not found: $topicPath" }

$facetPath = Join-Path $topicPath $Facet
if (-not (Test-Path $facetPath)) { New-Item -ItemType Directory -Path $facetPath -Force | Out-Null }

# --- Run it, capture everything, including failure ----------------------------
# ⭐ A failed command is often the evidence (break-fix). Capture the error text verbatim -
#    CONTENT-STANDARD.md requires verbatim error strings, not paraphrases.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$status = 'success'
try {
    $output = & $Command 2>&1 | Out-String
}
catch {
    $status = 'failed'
    $output = $_ | Out-String
}
$sw.Stop()

foreach ($p in $Redact) { $output = $output -replace $p, '$1[REDACTED]' }

# --- Context ------------------------------------------------------------------
$tenant = 'unknown'
try {
    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    if ($ctx) { $tenant = "$($ctx.TenantId) ($($ctx.Account))" }
} catch { }

$stamp = Get-Date
$file  = Join-Path $facetPath ("{0}-{1}.md" -f $stamp.ToString('yyyy-MM-dd'), $Name)

$body = @"
# $Name

> **Evidence artifact.** Captured by ``SC-300-SPRINT/New-LabEvidence.ps1``.
> Facet: ``$Facet`` · Topic: [``$Topic``](../README.md)

| Field | Value |
|---|---|
| Captured | $($stamp.ToString('yyyy-MM-dd HH:mm:ss zzz')) |
| Tenant | $tenant |
| Status | **$status** |
| Duration | $([math]::Round($sw.Elapsed.TotalSeconds,2))s |

## Why this is evidence

$Note

## Command

``````powershell
$($Command.ToString().Trim())
``````

## Output

``````
$($output.TrimEnd())
``````

---

> ⚠ Captured during the **Microsoft 365 E5 trial expiring 2026-09-10**. The configuration this
> describes will not survive the licence lapsing; this record is the point.
"@

Set-Content -Path $file -Value ($body -replace "`r`n", "`n") -Encoding utf8 -NoNewline

Write-Host ""
Write-Host "  [$status] evidence -> $($file.Replace($repo + '\', ''))" `
    -ForegroundColor $(if ($status -eq 'success') { 'Green' } else { 'Yellow' })

# --- Report facet coverage for this topic -------------------------------------
$FACETS = 'lab','security','operations','break-fix','customer-use-cases','architecture-decisions'
$filled = @($FACETS | Where-Object {
    $fp = Join-Path $topicPath $_
    (Test-Path $fp) -and @(Get-ChildItem $fp -File -Recurse -EA SilentlyContinue |
                            Where-Object Name -ne '.gitkeep').Count -gt 0
})

$state = if ($filled.Count -ge 3) { 'WRITTEN' } else { 'PARTIAL' }
Write-Host ("  facets: {0}/6 [{1}] -> {2}" -f $filled.Count, ($filled -join ', '), $state) `
    -ForegroundColor $(if ($state -eq 'WRITTEN') { 'Green' } else { 'DarkGray' })

if ($filled.Count -eq 3) {
    Write-Host "  ⭐ This topic just crossed into WRITTEN. Run tools/Build-CoverageRegister.ps1" -ForegroundColor Cyan
}
Write-Host ""

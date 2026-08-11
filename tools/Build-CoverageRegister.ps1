<#
.SYNOPSIS
    Generate COVERAGE.md from the filesystem. The repo's single source of truth for what
    is actually written versus what is merely scaffolded.

.DESCRIPTION
    Every topic folder in this repo ships a README declaring a five-part content contract
    (Fundamentals / Intermediate / Mastery / Labs / Customer delivery) and a hand-written
    "Status:" line.

    Hand-written status ALWAYS drifts. On 2026-08-09 the repo contained 1,023 directories,
    200 markdown files, and 9 documents with real depth - while every root-level index
    claimed broad coverage and not one of them referenced the seven layer documents that
    had just been written.

    This script removes the ability to lie. It walks the tree, measures actual content,
    classifies each topic, and regenerates COVERAGE.md. Run it after any content change;
    wire it into CI so a stale register fails the build.

.PARAMETER Path
    Repo root. Defaults to the parent of this script's directory.

.PARAMETER Check
    Exit non-zero if COVERAGE.md is out of date rather than rewriting it. For CI.

.EXAMPLE
    .\tools\Build-CoverageRegister.ps1
    .\tools\Build-CoverageRegister.ps1 -Check
#>
[CmdletBinding()]
param(
    [string]$Path = (Split-Path $PSScriptRoot -Parent),
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path $Path).Path

# --- The repo's own content contract -------------------------------------------
# A TOPIC is an immediate child directory of a numbered domain. Each topic ships six
# FACET folders that ARE the content contract. Measuring against these - rather than
# against an arbitrary byte count - is what makes this register meaningful: it says
# not just "unwritten" but "has the concept, has no lab evidence".
$FACETS = @('lab','security','operations','break-fix','customer-use-cases','architecture-decisions')

$SCAFFOLD_README_MAX = 1024   # the generated contract README is ~740 B

# --- Measure CONTENT, not storage ----------------------------------------------
# A file's meaning does not change with its line endings, but its BYTE COUNT does:
# CRLF costs one extra byte per line. Git checks this repo out with CRLF on Windows
# (core.autocrlf defaults to true, including on GitHub's windows-latest runners) and
# with LF elsewhere - so a raw .Length measurement makes this register PLATFORM
# DEPENDENT.
#
# That is not theoretical. It is why CI failed on 2026-08-10 and 2026-08-11 while
# -Check passed locally: 66 of 144 topics measured a different size on the runner
# than on the authoring machine, so a locally-correct COVERAGE.md could never match.
# An instrument whose reading depends on where you stand is not an instrument.
#
# Fix: subtract the CR of every CRLF pair before measuring. Latin-1 maps bytes 1:1
# to chars, so the scan is lossless and fast on binary content too.
$LATIN1 = [System.Text.Encoding]::GetEncoding('iso-8859-1')

function Get-ContentBytes {
    param([System.IO.FileInfo]$File)
    try {
        $raw = [System.IO.File]::ReadAllBytes($File.FullName)
        $crs = ([regex]::Matches($LATIN1.GetString($raw), "`r`n")).Count
        return $raw.Length - $crs
    } catch {
        return $File.Length
    }
}

function Measure-ContentBytes {
    param($Files)
    $sum = 0
    foreach ($f in $Files) { $sum += Get-ContentBytes $f }
    return $sum
}

function Get-TopicState {
    param([System.IO.DirectoryInfo]$Dir)

    # Prose sitting directly in the topic folder (README + any deep documents)
    $topFiles = Get-ChildItem $Dir.FullName -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne '.gitkeep' }
    $topBytes = Measure-ContentBytes $topFiles

    # Does real content exist beyond the generated scaffold README?
    $nonScaffold = $topFiles | Where-Object {
        $_.Name -ne 'README.md' -or (Get-ContentBytes $_) -gt $SCAFFOLD_README_MAX
    }
    $conceptBytes = Measure-ContentBytes $nonScaffold

    # Which facets have anything in them?
    $filled = @()
    foreach ($f in $FACETS) {
        $fp = Join-Path $Dir.FullName $f
        if (Test-Path $fp) {
            $c = Get-ChildItem $fp -File -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne '.gitkeep' }
            if ($c) { $filled += $f }
        }
    }
    $facetBytes = 0
    foreach ($f in $filled) {
        $facetBytes += Measure-ContentBytes (
            Get-ChildItem (Join-Path $Dir.FullName $f) -File -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne '.gitkeep' })
    }

    $total = $conceptBytes + $facetBytes

    # WRITTEN  = concept prose AND at least 3 of 6 facets carry evidence
    # PARTIAL  = concept prose exists, evidence thin
    # STUB     = scaffold README only
    # EMPTY    = not even that
    $state = if     ($total -eq 0 -and $topBytes -eq 0) { 'EMPTY' }
             elseif ($conceptBytes -eq 0)               { 'STUB' }
             elseif ($filled.Count -ge 3)               { 'WRITTEN' }
             else                                        { 'PARTIAL' }

    # --- Reading depth -------------------------------------------------------
    # Orthogonal to State. State measures EVIDENCE (did he do it in a tenant);
    # Depth measures READABILITY (can he learn the concept from this file at all).
    # A topic can be PARTIAL/DEEP (good study material, no lab yet) or
    # PARTIAL/THIN (prose that says nothing) - the old register conflated the two,
    # which is how 123 placeholder topics passed unnoticed. See CONTENT-STANDARD.md.
    $readme = Join-Path $Dir.FullName 'README.md'
    $depth = 'NONE'; $examples = 0
    if (Test-Path $readme) {
        $text     = Get-Content $readme -Raw -ErrorAction SilentlyContinue
        $examples = ([regex]::Matches($text, '(?m)^```')).Count / 2   # fenced blocks
        $kb       = (Get-ContentBytes (Get-Item $readme)) / 1KB
        $depth = if     ($kb -lt 1)                     { 'NONE' }   # scaffold
                 elseif ($kb -ge 8 -and $examples -ge 4){ 'DEEP' }   # meets the standard
                 elseif ($kb -ge 3)                     { 'THIN' }   # prose, few/no examples
                 else                                    { 'NONE' }
    }

    [pscustomobject]@{
        State    = $state
        Depth    = $depth
        Examples = [int]$examples
        Bytes    = $total
        Facets   = $filled
        FacetN   = $filled.Count
    }
}

# --- Walk ----------------------------------------------------------------------
$domains = Get-ChildItem $repo -Directory |
           Where-Object { $_.Name -match '^\d{2}-' } | Sort-Object Name

$rows = foreach ($d in $domains) {
    $topics = Get-ChildItem $d.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $topics) { $topics = @($d) }

    foreach ($t in $topics) {
        $s = Get-TopicState $t
        [pscustomobject]@{
            Domain  = $d.Name
            Topic   = $t.FullName.Replace("$repo\", '').Replace('\', '/')
            State   = $s.State
            Depth   = $s.Depth
            Examples= $s.Examples
            KB      = [math]::Round($s.Bytes / 1KB, 1)
            FacetN  = $s.FacetN
            Missing = (@($FACETS | Where-Object { $_ -notin $s.Facets }) -join ', ')
        }
    }
}

# Deep documents live above the leaf level - count them separately
$layers = Get-ChildItem $repo -Recurse -File -Filter 'LAYER-*.md' -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -notmatch '\\\.git\\' } | Sort-Object Name

$total   = $rows.Count
$written = ($rows | Where-Object State -eq 'WRITTEN').Count
$partial = ($rows | Where-Object State -eq 'PARTIAL').Count
$stub    = ($rows | Where-Object State -eq 'STUB').Count
$empty   = ($rows | Where-Object State -eq 'EMPTY').Count
$pct     = if ($total) { [math]::Round(100 * $written / $total, 1) } else { 0 }

$deep     = ($rows | Where-Object Depth -eq 'DEEP').Count
$thin     = ($rows | Where-Object Depth -eq 'THIN').Count
$nodepth  = ($rows | Where-Object Depth -eq 'NONE').Count
$deepPct  = if ($total) { [math]::Round(100 * $deep / $total, 1) } else { 0 }

# --- Render --------------------------------------------------------------------
$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('# Coverage Register')
$null = $sb.AppendLine()
$null = $sb.AppendLine('> **Generated by `tools/Build-CoverageRegister.ps1`. Do not edit by hand.**')
$null = $sb.AppendLine('> Regenerate after any content change. A hand-maintained register drifts;')
$null = $sb.AppendLine('> this one is measured from the filesystem, so the repo cannot overstate itself.')
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Reading depth - can you actually study from this?')
$null = $sb.AppendLine()
$null = $sb.AppendLine('**State** below measures *evidence* (was it done in a tenant). **Depth** measures')
$null = $sb.AppendLine('*readability* - whether the README teaches the concept with worked examples, per')
$null = $sb.AppendLine('[`CONTENT-STANDARD.md`](CONTENT-STANDARD.md). These are independent, and conflating')
$null = $sb.AppendLine('them is how 123 placeholder topics went unnoticed.')
$null = $sb.AppendLine()
$null = $sb.AppendLine("| Depth | Meaning | Count | Share |")
$null = $sb.AppendLine("|---|---|---:|---:|")
$null = $sb.AppendLine("| **DEEP** | >=8 KB **and** >=4 worked examples - meets the standard | $deep | $deepPct% |")
$null = $sb.AppendLine("| THIN | >=3 KB prose, few or no worked examples | $thin | $([math]::Round(100*$thin/[math]::Max($total,1),1))% |")
$null = $sb.AppendLine("| NONE | Placeholder or near-empty - **not study material** | $nodepth | $([math]::Round(100*$nodepth/[math]::Max($total,1),1))% |")
$null = $sb.AppendLine()
$null = $sb.AppendLine('## Honest state')
$null = $sb.AppendLine()
$null = $sb.AppendLine('Each topic ships six facet folders that **are** the content contract:')
$null = $sb.AppendLine('`lab` · `security` · `operations` · `break-fix` · `customer-use-cases` · `architecture-decisions`.')
$null = $sb.AppendLine()
$null = $sb.AppendLine("| State | Meaning | Count | Share |")
$null = $sb.AppendLine("|---|---|---:|---:|")
$null = $sb.AppendLine("| **WRITTEN** | Concept prose **and** >=3 of 6 facets carry evidence | $written | $pct% |")
$null = $sb.AppendLine("| PARTIAL | Concept prose exists, evidence thin (<3 facets) | $partial | $([math]::Round(100*$partial/[math]::Max($total,1),1))% |")
$null = $sb.AppendLine("| STUB | Scaffold README only - nothing written | $stub | $([math]::Round(100*$stub/[math]::Max($total,1),1))% |")
$null = $sb.AppendLine("| EMPTY | Not even a README | $empty | $([math]::Round(100*$empty/[math]::Max($total,1),1))% |")
$null = $sb.AppendLine("| | **Total topics** | **$total** | |")
$null = $sb.AppendLine()
$null = $sb.AppendLine("**$written of $total topics are written. The rest is scaffold.**")
$null = $sb.AppendLine()
$null = $sb.AppendLine('Scaffold is a plan, not knowledge. A folder existing proves nothing was studied.')
$null = $sb.AppendLine('Treat every non-WRITTEN topic as unstudied, and note that even WRITTEN means')
$null = $sb.AppendLine('*documented* - it does not mean the labs were run in a live tenant.')
$null = $sb.AppendLine()

# Deep documents
$null = $sb.AppendLine('## Deep documents')
$null = $sb.AppendLine()
if ($layers) {
    $null = $sb.AppendLine('| Document | KB |')
    $null = $sb.AppendLine('|---|---:|')
    foreach ($l in $layers) {
        $rel = $l.FullName.Replace("$repo\", '').Replace('\', '/')
        $null = $sb.AppendLine("| [$($l.Name)]($rel) | $([math]::Round((Get-ContentBytes $l)/1KB,1)) |")
    }
} else {
    $null = $sb.AppendLine('_None found._')
}
$null = $sb.AppendLine()

# Per-domain rollup
$null = $sb.AppendLine('## By domain')
$null = $sb.AppendLine()
$null = $sb.AppendLine('| Domain | Topics | Written | Partial | Stub | Empty |')
$null = $sb.AppendLine('|---|---:|---:|---:|---:|---:|')
foreach ($g in ($rows | Group-Object Domain | Sort-Object Name)) {
    $w = ($g.Group | Where-Object State -eq 'WRITTEN').Count
    $p = ($g.Group | Where-Object State -eq 'PARTIAL').Count
    $s = ($g.Group | Where-Object State -eq 'STUB').Count
    $e = ($g.Group | Where-Object State -eq 'EMPTY').Count
    $null = $sb.AppendLine("| ``$($g.Name)`` | $($g.Count) | $w | $p | $s | $e |")
}
$null = $sb.AppendLine()

# Full topic listing
$null = $sb.AppendLine('## Every topic')
$null = $sb.AppendLine()
$null = $sb.AppendLine('`Facets` = how many of the six evidence folders carry anything. `Missing` names the gaps.')
$null = $sb.AppendLine()
$null = $sb.AppendLine('| State | Topic | KB | Facets | Missing |')
$null = $sb.AppendLine('|---|---|---:|---:|---|')
$order = @{ 'WRITTEN'=0; 'PARTIAL'=1; 'STUB'=2; 'EMPTY'=3 }
foreach ($r in ($rows | Sort-Object @{e={$order[$_.State]}}, Topic)) {
    $badge = switch ($r.State) {
        'WRITTEN' { '**WRITTEN**' }
        'PARTIAL' { 'PARTIAL' }
        'STUB'    { 'stub' }
        'EMPTY'   { 'empty' }
    }
    $miss = if ($r.Missing) { $r.Missing } else { '—' }
    $null = $sb.AppendLine("| $badge | ``$($r.Topic)`` | $($r.KB) | $($r.FacetN)/6 | $miss |")
}

$content = $sb.ToString()
$target  = Join-Path $repo 'COVERAGE.md'

if ($Check) {
    $existing = if (Test-Path $target) { Get-Content $target -Raw } else { '' }
    # Compare TEXT, not bytes - for the same reason the sizes above are normalised.
    # Otherwise a CRLF checkout fails against an LF-authored register even when every
    # measurement agrees, and the failure looks like stale content rather than a
    # line-ending artefact. That misdiagnosis cost a red build for two days.
    $norm = { param($s) ($s -replace "`r`n", "`n").TrimEnd() }
    if ((& $norm $existing) -ne (& $norm $content)) {
        Write-Host "COVERAGE.md is STALE. Run tools/Build-CoverageRegister.ps1" -ForegroundColor Red
        exit 1
    }
    Write-Host "COVERAGE.md is current." -ForegroundColor Green
    exit 0
}

# Write LF, matching .gitattributes. AppendLine emits the platform newline, which on
# Windows would put CRLF in a file the repo has declared LF - a diff on every run.
[System.IO.File]::WriteAllText($target, ($content -replace "`r`n", "`n"),
    (New-Object System.Text.UTF8Encoding $false))
Write-Host "Wrote $target" -ForegroundColor Green
Write-Host "  WRITTEN $written / $total  ($pct%)   PARTIAL $partial   STUB $stub   EMPTY $empty"
Write-Host "  DEEP    $deep / $total  ($deepPct%)   THIN $thin   NONE $nodepth   <- reading depth"

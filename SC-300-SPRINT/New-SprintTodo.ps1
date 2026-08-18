<#
.SYNOPSIS
    Reviews your Microsoft To Do, reports what is wrong with it, and creates the SC-300 sprint
    tasks for today. Read-only until you pass -Apply.

.DESCRIPTION
    ⭐ Runs against Microsoft To Do through Microsoft Graph, using REST rather than the typed
    cmdlets - because Get-MgUserTodoListTask is absent from some Microsoft.Graph.Users builds
    (verified missing on 2.39.0), and a script that breaks on a module upgrade is not a tool.

    THREE MODES, and the default one changes nothing:

      (no switch)   ⭐ REVIEW ONLY. Lists every list, counts tasks, and flags:
                    overdue, no due date, stale (>90 days open), duplicate titles across
                    lists, and "graveyard" lists with a large open backlog.

      -Apply        Creates the list "SC-300 Sprint" and adds today's Day 1 + Day 2 tasks.
                    ⭐ Idempotent - a task whose title already exists in that list is skipped,
                    so re-running never duplicates.

      -FixOverdue   Moves OPEN overdue tasks to today's date. ⭐ Reversible, and every change
                    is printed. Nothing is completed and NOTHING IS EVER DELETED by this
                    script - deletion candidates are printed as suggestions for you to action.

.EXAMPLE
    .\New-SprintTodo.ps1                        # review only - start here
    .\New-SprintTodo.ps1 -Apply                 # create today's tasks
    .\New-SprintTodo.ps1 -Apply -FixOverdue     # and reschedule overdue items to today
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$FixOverdue,
    [string]$ListName = 'SC-300 Sprint',
    # ⭐ To Do stores a dateTime + zone. Wrong zone = task appears on the wrong day.
    [string]$TimeZone = 'India Standard Time',
    [int]$StaleDays  = 90
)

$ErrorActionPreference = 'Stop'
$today = Get-Date
$dueIso = $today.ToString('yyyy-MM-ddT23:00:00')

function Say { param($T,$C='Gray') Write-Host $T -ForegroundColor $C }

# --- 1. Connection ------------------------------------------------------------
$need = 'Tasks.ReadWrite'
$ctx = try { Get-MgContext } catch { $null }
if (-not $ctx -or $need -notin $ctx.Scopes) {
    Say "Connecting with $need ..." Cyan
    # ⭐ Reconnect rather than reuse: an existing narrower session silently wins, and the
    #    failure then looks like a permission bug. TROUBLESHOOTING.md sec.1.
    Connect-MgGraph -Scopes $need -NoWelcome
    $ctx = Get-MgContext
}
Say "Signed in as $($ctx.Account)" Green

function Graph {
    param([string]$Method,[string]$Uri,[hashtable]$Body)
    $p = @{ Method = $Method; Uri = $Uri; OutputType = 'PSObject' }
    if ($Body) { $p.Body = ($Body | ConvertTo-Json -Depth 6); $p.ContentType = 'application/json' }
    Invoke-MgGraphRequest @p
}
function GraphAll {
    param([string]$Uri)
    $out = @(); $next = $Uri
    while ($next) {
        $r = Graph -Method GET -Uri $next
        $out += $r.value
        $next = $r.'@odata.nextLink'
    }
    $out
}

# --- 2. Review ----------------------------------------------------------------
Say ''
Say ("=" * 66)
Say "MICROSOFT TO DO - REVIEW    $($today.ToString('yyyy-MM-dd HH:mm'))" Cyan
Say ("=" * 66)

$lists = GraphAll '/v1.0/me/todo/lists'
$all = @()
foreach ($l in $lists) {
    $tasks = GraphAll "/v1.0/me/todo/lists/$($l.id)/tasks?`$top=100"
    foreach ($t in $tasks) {
        $due = if ($t.dueDateTime) { [datetime]$t.dueDateTime.dateTime } else { $null }
        $all += [pscustomobject]@{
            List      = $l.displayName
            ListId    = $l.id
            TaskId    = $t.id
            Title     = $t.title
            Status    = $t.status
            Open      = ($t.status -ne 'completed')
            Due       = $due
            Created   = if ($t.createdDateTime) { [datetime]$t.createdDateTime } else { $null }
            Importance= $t.importance
        }
    }
}

$open = @($all | Where-Object Open)
Say ''
Say ("{0,-34} {1,6} {2,6} {3,8}" -f 'LIST','TOTAL','OPEN','OVERDUE') White
foreach ($l in $lists) {
    $t = @($all  | Where-Object List -eq $l.displayName)
    $o = @($open | Where-Object List -eq $l.displayName)
    $od= @($o    | Where-Object { $_.Due -and $_.Due.Date -lt $today.Date })
    $c = if ($od.Count -gt 0) { 'Yellow' } else { 'Gray' }
    Say ("{0,-34} {1,6} {2,6} {3,8}" -f $l.displayName, $t.Count, $o.Count, $od.Count) $c
}

# ⭐ The findings. Each one names the fix.
Say ''
Say 'FINDINGS' White
$findings = 0

$overdue = @($open | Where-Object { $_.Due -and $_.Due.Date -lt $today.Date } | Sort-Object Due)
if ($overdue.Count) {
    $findings++
    Say "  [!] $($overdue.Count) overdue and still open. Oldest: $($overdue[0].Due.ToString('yyyy-MM-dd')) - '$($overdue[0].Title)'" Yellow
    Say "      FIX: re-run with -FixOverdue to move them to today, or close them honestly." Cyan
    $overdue | Select-Object -First 5 | ForEach-Object {
        Say ("      - {0}  [{1}]  {2}" -f $_.Due.ToString('yyyy-MM-dd'), $_.List, $_.Title) DarkGray }
}

$noDue = @($open | Where-Object { -not $_.Due })
if ($noDue.Count) {
    $findings++
    Say "  [!] $($noDue.Count) open with NO due date." Yellow
    Say "      A task with no date is a wish. Give it a date or delete it." Cyan
}

$stale = @($open | Where-Object { $_.Created -and $_.Created -lt $today.AddDays(-$StaleDays) })
if ($stale.Count) {
    $findings++
    Say "  [!] $($stale.Count) open for more than $StaleDays days." Yellow
    Say "      DELETION CANDIDATES - this script never deletes. Review and clear them yourself:" Cyan
    $stale | Sort-Object Created | Select-Object -First 5 | ForEach-Object {
        Say ("      - {0} old  [{1}]  {2}" -f ([int]($today - $_.Created).TotalDays), $_.List, $_.Title) DarkGray }
}

$dupes = @($open | Group-Object Title | Where-Object Count -gt 1)
if ($dupes.Count) {
    $findings++
    Say "  [!] $($dupes.Count) duplicate title(s) across lists." Yellow
    $dupes | Select-Object -First 3 | ForEach-Object {
        Say ("      - '{0}' x{1} in: {2}" -f $_.Name, $_.Count, (($_.Group.List | Select-Object -Unique) -join ', ')) DarkGray }
}

$graveyards = @($lists | Where-Object { @($open | Where-Object List -eq $_.displayName).Count -ge 30 })
if ($graveyards.Count) {
    $findings++
    Say "  [!] Graveyard list(s): $(($graveyards.displayName) -join ', ')" Yellow
    Say "      30+ open items means the list is no longer read. Split it or clear it." Cyan
}

if (-not $findings) { Say '  [OK] Nothing to flag.' Green }

# --- 3. Fix (opt-in, reversible, never destructive) ---------------------------
if ($FixOverdue -and $overdue.Count) {
    Say ''
    Say "RESCHEDULING $($overdue.Count) overdue task(s) to today" Cyan
    foreach ($t in $overdue) {
        Graph -Method PATCH -Uri "/v1.0/me/todo/lists/$($t.ListId)/tasks/$($t.TaskId)" -Body @{
            dueDateTime = @{ dateTime = $dueIso; timeZone = $TimeZone } } | Out-Null
        Say ("  moved {0} -> today : {1}" -f $t.Due.ToString('yyyy-MM-dd'), $t.Title) DarkGray
    }
}

# --- 4. Today's tasks ---------------------------------------------------------
# ⭐ Day 1 is 3-4 h; Day 2 is ~8 h. Both in one day is ~12 h and is not realistic.
#    Tasks 1-6 are the ones that must land today - see the note in task 3.
$tasks = @(
 @{ n=1;  must=$true;  hi=$false; t='D1.1 - Verify what actually landed (20m)'
    b='Day0-Verify-Tenant.ps1 -OutFile .\evidence\day0-licence-state.json. DONE WHEN: SPE_E5 present (not ENTERPRISEPREMIUM alone - that is O365 E5 with no Entra P2), AAD_PREMIUM_P2 = Success, and YOUR account is licensed. A licence in the tenant does nothing until assigned. See DAY-1.md Lab 1.1.' }

 @{ n=2;  must=$true;  hi=$true;  t='D1.2 - Break-glass x2, created AND signed into (30m)'
    b='Day1-New-BreakGlass.ps1 -Apply. Then VERIFY by reading the role back, and SIGN IN with one account in a private window today. An account that exists but has never been signed into is a belief, not a control. Passwords stay in %USERPROFILE%\.breakglass - never on screen. DAY-1.md Lab 1.2.' }

 @{ n=3;  must=$true;  hi=$true;  t='D1.3 - Enable telemetry - HIGHEST LEVERAGE TASK TODAY (45m)'
    b='Day1-Enable-Telemetry.ps1 -Apply, plus the portal-side items in DAY-1.md Lab 1.3. WHY THIS ONE FIRST: telemetry captures FORWARD ONLY. Every day it is off is a day of risk detections and sign-in baseline you can never recover, and the trial ends 2026-09-10. If you do one thing today, do this.' }

 @{ n=4;  must=$true;  hi=$false; t='D1.4 - Seed the lab org: 16 users, dynamic groups (30m)'
    b='..\30-identity-and-nhi\entra-users-and-groups\Seed-LabTenant.ps1 (dry run first, then -Apply). A pristine tenant generates no signal: dynamic groups need attributes, access reviews need a manager chain, PIM needs someone to elevate. Create the mess before practising cleaning it. DAY-1.md Lab 1.4.' }

 @{ n=5;  must=$true;  hi=$false; t='D1.5 - Break a dynamic rule on purpose, record the error (20m)'
    b='Set a membership rule with an unclosed bracket. Record the VERBATIM error, fix it, and MEASURE how long re-evaluation takes. That lag is the answer to "I added the attribute, why is the user not in the group?" - the most common dynamic-group ticket, and not a bug. DAY-1.md.' }

 @{ n=6;  must=$true;  hi=$false; t='D1.6 - Capture evidence + commit (15m)'
    b='New-LabEvidence.ps1 for each lab, then Build-CoverageRegister.ps1, then commit and push. Evidence is the repo gap: 144/144 topics are written, 0/144 carry artifacts. Three files today gives you your first WRITTEN topic.' }

 @{ n=7;  must=$false; hi=$false; t='D2.1 - Measure BEFORE you change anything (45m)'
    b='Capture what is enabled tenant-wide AND what users have actually REGISTERED. This is the BEFORE half of a before/after evidence pair - it cannot be recreated later. Highest-value query: admins with no MFA registered. DAY-2.md Lab 2.1.' }

 @{ n=8;  must=$false; hi=$false; t='D2.2 - Temporary Access Pass: enable, issue, register (1h)'
    b='TAP is a named exam objective with NO official Microsoft lab. It resolves the passwordless chicken-and-egg: you cannot register a passkey without signing in, and cannot sign in without a credential. Naming TAP as the bootstrap is interview-grade. DAY-2.md Lab 2.2.' }

 @{ n=9;  must=$false; hi=$false; t='D2.3 - Method ladder: number matching + FIDO2 (1.5h)'
    b='Enable Authenticator number matching and additional context, then register a passkey. Know WHY number matching exists: push-fatigue attacks worked. Knowing why a control exists is what separates you in an interview. DAY-2.md Lab 2.3.' }

 @{ n=10; must=$false; hi=$false; t='D2.4 - Custom authentication strength (1h)'
    b='Create a custom strength allowing ONLY phishing-resistant methods. You attach it to a CA policy on Day 3. This is how "require MFA" becomes "require THIS KIND of MFA". DAY-2.md Lab 2.4.' }

 @{ n=11; must=$false; hi=$false; t='D2.5 - SSPR, registration campaign, banned passwords (2h)'
    b='Enable SSPR, start the registration campaign, add your own banned-password list. Registration BEFORE enforcement is the whole game - after enforcement it is a support incident. DAY-2.md Lab 2.5.' }

 @{ n=12; must=$false; hi=$false; t='D2.6 - Legacy auth drill: watch MFA never prompt (1h)'
    b='Attempt IMAP/SMTP AUTH and observe that MFA is NEVER prompted - the protocol cannot carry the challenge. Then say the sentence out loud: "Block legacy authentication first, because a protocol that cannot carry an MFA challenge silently bypasses every MFA policy you write." DAY-2.md Lab 2.6.' }

 @{ n=13; must=$false; hi=$false; t='D2.7 - Capture AFTER state + commit (30m)'
    b='Re-run the Lab 2.1 queries. The before/after pair is what survives the trial expiring on 2026-09-10. Three evidence files today should make authentication-methods your first WRITTEN topic. DAY-2.md Close out.' }
)

if (-not $Apply) {
    Say ''
    Say ("=" * 66)
    Say "WOULD CREATE $($tasks.Count) task(s) in list '$ListName', due today." Cyan
    Say '  Re-run with -Apply to create them.' Cyan
    $tasks | ForEach-Object { Say ("  {0,2}. {1}{2}" -f $_.n, $_.t, $(if($_.must){'   [MUST TODAY]'}else{''})) DarkGray }
    Say ''
    Say 'REALITY CHECK: Day 1 is 3-4 h, Day 2 is ~8 h. Together that is ~12 h.' Yellow
    Say 'Tasks 1-6 are the ones that must land today. Task 3 is the one that cannot wait.' Yellow
    return
}

# --- 5. Create ----------------------------------------------------------------
$list = $lists | Where-Object displayName -eq $ListName | Select-Object -First 1
if (-not $list) {
    $list = Graph -Method POST -Uri '/v1.0/me/todo/lists' -Body @{ displayName = $ListName }
    Say ''
    Say "Created list '$ListName'" Green
} else {
    Say ''
    Say "Using existing list '$ListName'" Green
}

$existing = @(GraphAll "/v1.0/me/todo/lists/$($list.id)/tasks?`$top=100").title
$made = 0; $skipped = 0
foreach ($t in $tasks) {
    if ($existing -contains $t.t) { $skipped++; continue }   # ⭐ idempotent
    $body = @{
        title       = $t.t
        body        = @{ content = $t.b; contentType = 'text' }
        dueDateTime = @{ dateTime = $dueIso; timeZone = $TimeZone }
        importance  = $(if ($t.hi) { 'high' } else { 'normal' })
    }
    Graph -Method POST -Uri "/v1.0/me/todo/lists/$($list.id)/tasks" -Body $body | Out-Null
    Say ("  + {0}" -f $t.t) DarkGray
    $made++
}

Say ''
Say ("Created $made, skipped $skipped already present.") Green
Say ''
Say 'Open To Do and work tasks 1-6 in order. Task 3 is the one that cannot wait a day.' Cyan

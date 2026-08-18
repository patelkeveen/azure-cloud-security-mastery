# Runbooks (operational and automated)

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** procedures you **hand to a customer** are
> [`../../75-architecture-and-consulting/sop-and-runbooks/`](../../75-architecture-and-consulting/sop-and-runbooks/).
> ⭐ **This topic is the operational article: the ladder from a written procedure to executable
> automation, and Azure Automation runbooks as a product.**

---

## 1. What it is

Two things that share a name, and both matter:

| Sense | Meaning |
|---|---|
| ⭐ **Procedural runbook** | the written steps for one scenario, followed by a human |
| ⭐ **Azure Automation runbook** | a PowerShell/Python script that ⭐ **runs itself**, on a schedule or from an alert |

⭐ **These are the two ends of one ladder, and the whole discipline is climbing it deliberately.**

---

## 2. Why it exists

⭐ **Every manual procedure performed repeatedly is a defect waiting for a bad night.** The cost is
not the minutes — it is the variance:

| Manual procedure | ⭐ What actually goes wrong |
|---|---|
| 12 steps, weekly | ⭐ step 7 skipped when someone is rushed |
| Requires elevated rights | ⭐ standing admin access, kept "for the runbook" |
| Different engineer each time | ⭐ different result each time |
| ⭐ Performed at 03:00 | ⭐ **worst version of the person doing it** |
| Undocumented tribal knowledge | ⭐ one person owns it; ⭐ they go on leave |

⭐ **The second row is the security consequence people miss.** ⭐ **Manual procedures are the most
common justification for standing privilege** — *"the on-call needs Global Admin because of the
runbook"* — and automating the procedure is what makes just-in-time access viable at all.

---

## 3. How it works underneath — the automation ladder

```
① ⭐ TRIBAL       in someone's head        ⭐ risk: they leave
        ▼
② WRITTEN        markdown, followed by hand    ⭐ risk: drift, skipped steps
        ▼
③ ⭐ SCRIPTED     a script the human runs       ⭐ risk: run from a laptop,
        ▼                                          with personal credentials
④ ⭐ AUTOMATED    ⭐ Azure Automation runbook
        │         ⭐ + MANAGED IDENTITY (⭐ no stored secret)
        │         ⭐ + source-controlled, logged, ⭐ auditable
        ▼
⑤ ⭐ SELF-HEALING alert ──► webhook ──► runbook ──► ⭐ fixes, then reports
                  ⭐ risk: hides a worsening problem ← ⭐ see §7
```

⭐ **Step ③ → ④ is the one with real security value.** A script run from an engineer's laptop uses
*their* credentials, leaves no central log, and works only when they are awake. ⭐ **The same script
in Azure Automation runs under a managed identity with a scoped role, produces a job record, and has
a version history** — the identity argument from
[`../../30-identity-and-nhi/managed-identities/`](../../30-identity-and-nhi/managed-identities/),
applied to operations.

⭐ **Do not skip to ⑤.** Self-healing that nobody measures ⭐ **converts a visible failure into an
invisible recurring one.**

---

## 4. Worked example — climbing from ③ to ④

**Automation account with a managed identity — ⭐ note there is no secret anywhere:**

```powershell
$aa = New-AzAutomationAccount -Name 'aa-contoso-ops' -ResourceGroupName rg-ops `
        -Location westeurope -AssignSystemIdentity

# ⭐ Least privilege: this runbook restarts app services. Nothing more.
New-AzRoleAssignment -ObjectId $aa.Identity.PrincipalId `
  -RoleDefinitionName 'Website Contributor' `
  -Scope '/subscriptions/<sub>/resourceGroups/rg-app-prod'
```

⭐ **`Website Contributor` scoped to one resource group — not Contributor at subscription scope.**
⭐ **The most common Azure Automation anti-pattern is an automation account with Owner on the
subscription**, because it was easier during testing and nobody revisited it. That identity is then
a standing, non-human path to full control, and it appears in no access review.

**The runbook itself — ⭐ the structure matters more than the logic:**

```powershell
<#  RB-OPS-012  Restart App Service when unhealthy
    Trigger : alert webhook, or manual
    ⭐ Identity: system-assigned MI of aa-contoso-ops (Website Contributor / rg-app-prod)
    ⭐ Last tested: 2026-08-12 by D. Mwangi                                        #>
param(
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [switch]$WhatIf                                    # ⭐ dry run FIRST
)
$ErrorActionPreference = 'Stop'                        # ⭐ load-bearing

Connect-AzAccount -Identity | Out-Null                 # ⭐ no credential to leak

$app = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppName
Write-Output "PRE  : $($app.Name) state=$($app.State)"

if ($WhatIf) { Write-Output 'WHATIF: would restart'; return }

Restart-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppName | Out-Null
Start-Sleep -Seconds 30

# ⭐ POST-CONDITION - never trust the call, read the state back
$after = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppName
Write-Output "POST : $($after.Name) state=$($after.State)"
if ($after.State -ne 'Running') { throw "⭐ FAILED: state is $($after.State)" }
```

```
PRE  : app-contoso-prod state=Running
POST : app-contoso-prod state=Running
```

⭐ **Three properties make this a runbook rather than a script**, and each one has been learned the
hard way:

1. ⭐ **`-WhatIf`** — an automated action you cannot dry-run will eventually be run against the wrong
   target.
2. ⭐ **`$ErrorActionPreference = 'Stop'`** — ⭐ **PowerShell's default is to continue on
   non-terminating errors**, so a failed step lets the script march on and report success. This is
   exactly the defect recorded in
   [`../../SC-300-SPRINT/TROUBLESHOOTING.md`](../../SC-300-SPRINT/TROUBLESHOOTING.md) §2.
3. ⭐ **The post-condition read-back** — ⭐ **an API call returning 200 is not evidence the state
   changed.** Read it back, and throw if it is wrong.

⭐ **`Last tested`, not `Last updated`, in the header** — same rule as the customer-facing procedures.

---

## 5. Commands — did it actually run, and did it work?

```powershell
Get-AzAutomationJob -AutomationAccountName aa-contoso-ops -ResourceGroupName rg-ops |
  Select-Object RunbookName, Status, StartTime, EndTime |
  Sort-Object StartTime -Descending | Select-Object -First 5
```

```
RunbookName          Status     StartTime            EndTime
RB-OPS-012-Restart   Completed  14/08/2026 09:22:10  14/08/2026 09:22:51
RB-OPS-012-Restart   Completed  14/08/2026 07:41:02  07:41:44
RB-OPS-012-Restart   Completed  14/08/2026 06:03:55  06:04:38
RB-OPS-004-Cleanup   Failed     13/08/2026 02:00:00  02:00:12
```

⭐ **Read that output as an operator: the restart runbook ran three times in four hours.** ⭐ **Each
run "succeeded" — and that is the problem.** The automation is successfully hiding an application
that is failing every ninety minutes. ⭐ **Self-healing without a counter is how a degrading system
stays invisible until it fails completely.**

⭐ **Rule: every self-healing runbook increments something, and something alerts on the rate.**
*"Restarted once"* is a fix; *"restarted three times in four hours"* is an incident.

```powershell
# ⭐ The failing one - read the actual error, not the status
Get-AzAutomationJobOutput -AutomationAccountName aa-contoso-ops -ResourceGroupName rg-ops `
  -Id $jobId -Stream Error | Select-Object -ExpandProperty Summary
```

```
The client 'aa-contoso-ops' with object id '...' does not have authorization to
perform action 'Microsoft.Storage/storageAccounts/delete' over scope '...'
```

⭐ **A permission error, not a logic error** — and the correct response is to ask whether the runbook
*should* have that permission, not to grant it reflexively. ⭐ **"The automation failed, so we gave
it Contributor" is how automation accounts become the most over-privileged identities in a
subscription.**

---

## 6. When and where

| Frequency × risk | Rung to aim for |
|---|---|
| Rare, high-judgement | ⭐ ② written — ⭐ **do not automate a decision** |
| Weekly, mechanical | ③ → ④ |
| ⭐ Daily or on-alert, mechanical | ⭐ ④ automated, ⭐ with a job record |
| ⭐ Known transient fault | ⑤ self-healing ⭐ **+ a rate alert** |
| ⭐ Anything destructive | ⭐ stay at ③ with a human, or ⭐ require approval |

⭐ **Never automate a decision — automate the execution of a decision already made.** A runbook that
chooses *whether* to fail over has replaced an incident commander with a script, and it will make
that choice during exactly the ambiguous conditions a human should be judging.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Runbook reports success, nothing changed | ⭐ no post-condition | ⭐ read the state back and throw |
| ⭐ Script "worked" despite an error | ⭐ default `ErrorActionPreference` | ⭐ set to `Stop` |
| ⭐ Problem invisible for weeks | ⭐ self-healing with no counter | ⭐ alert on remediation **rate** |
| Automation account is Owner | ⭐ convenience during testing | scope to the minimum role |
| Runbook fails after a rotation | ⭐ stored credential expired | ⭐ managed identity — no secret |
| Nobody knows if it still works | never tested | ⭐ `Last tested` + scheduled dry run |
| ⭐ Ran against the wrong resource | no `-WhatIf` | add it, and use it |

⭐ **The self-healing failure is the subtle one and worth stating plainly: automation that fixes a
symptom removes the pressure to fix the cause.** ⭐ **The remediation counter is what preserves that
pressure** — it turns silent repair into a visible trend.

---

## 8. Customer discovery questions

1. ⭐ **"Which manual tasks do you perform more than weekly?"** — the automation candidates
2. ⭐ **"Does anyone hold standing admin rights only because of a manual procedure?"**
3. "Where do your scripts run — a laptop, a server, or Automation?"
4. ⭐ **"Do any of your automations use a stored credential or a secret?"**
5. "If a self-healing action fired ten times today, would anyone know?"
6. ⭐ **"What permissions does your automation account hold, and at what scope?"**
7. "When was each runbook last executed successfully?"

---

## 9. Remember it

**Hook — the ladder `T W S A H`: Tribal → Written → Scripted → Automated → self-Healing.**
⭐ **Climb one rung at a time; ⭐ rung five needs a counter.**

**Analogy — a hospital's automatic backup generator.** ⭐ **It starts by itself, which is exactly
right — but if nobody logs how often mains power failed, the hospital discovers the pattern only
when the generator finally does not start.** The analogy predicts both key rules: ⭐ **automate the
execution (the generator starts itself) but never the decision (a human decides whether to evacuate)**,
and ⭐ **count every activation, because the count is the real signal.**

**The one line:** ⭐ **Automate execution, never judgement — use a managed identity, read the state
back, and count every self-healing action.**

---

## 10. Self-test

1. Name the five rungs of the automation ladder.
   → ⭐ Tribal, Written, Scripted, Automated, Self-healing.
2. Which rung transition has the biggest security benefit, and why?
   → ⭐ Scripted → Automated: managed identity, scoped role, central job log, no personal credentials.
3. Why is `$ErrorActionPreference = 'Stop'` load-bearing?
   → ⭐ PowerShell continues on non-terminating errors, so a failed step can report success.
4. What must every runbook do after acting?
   → ⭐ Read the state back and throw if it is wrong. A 200 is not evidence.
5. The danger of self-healing?
   → ⭐ It hides a worsening problem. Count remediations and alert on the rate.
6. Why should automation identities never be Owner?
   → ⭐ A standing, non-human path to full control that appears in no access review.
7. What must never be automated?
   → ⭐ The decision. Automate the execution of a decision already made.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one runbook running under a managed identity, with the job output |
| `security` | ⭐ the automation identity's role and scope, showing least privilege |
| `operations` | ⭐ the remediation counter and the rate alert built on it |
| `break-fix` | one runbook that reported success while failing, and the post-condition that caught it |
| `architecture-decisions` | ⭐ one procedure deliberately **left** manual, with the reason |

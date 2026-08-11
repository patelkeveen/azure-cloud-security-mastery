# Lifecycle Workflows

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ✅ Verified against Microsoft Learn **2026-08-10** (licensing updated 2026-07-30).
> ⚠ **Requires the Microsoft Entra ID Governance SKU — not included in P2 at any level.**

---

## 1. What it is

Automating the **joiner–mover–leaver** process against attributes already in the directory: run a
set of tasks a number of days **before, on, or after** someone's `employeeHireDate` or
`employeeLeaveDateTime`.

```
TRIGGER          attribute + offset      "7 days before employeeHireDate"
   └─ SCOPE      a rule selecting users  "department eq 'Sales'"
        └─ TASKS ordered actions         generate TAP · email manager · add to groups
```

---

## 2. Why it exists — and the security case, not the HR one

Joiner–mover–leaver is usually pitched as HR efficiency. **The security case is stronger:**

- **The leaver who was never disabled** is the most common finding in any identity assessment
- **Offboarding depends on a human being told**, and during redundancies or a resignation nobody
  processes, they are not told
- **Movers keep everything** — the accumulation problem
  [`../entitlement-management/`](../entitlement-management/) §2 describes

> ⭐ **The point is removing the human dependency from the leaver path.** `employeeLeaveDateTime` is
> already in the directory because HR put it there. A workflow acts on it whether or not anyone
> remembers to raise a ticket.

**Pair it with session revocation.** Disabling an account does not evict live tokens — see
[`../../50-security-operations/incident-response/`](../../50-security-operations/incident-response/) §5.
A leaver workflow that only disables the account leaves refresh tokens working.

---

## 3. ⚠ Licensing — the boundary that ends most conversations ✅

| Feature | Free | P1 | **P2** | **ID Governance** | Entra Suite |
|---|:---:|:---:|:---:|:---:|:---:|
| **Lifecycle Workflows** | ✗ | ✗ | ⭐ **✗** | **✅** | ✅ |
| LCW + custom extensions (Logic Apps) | ✗ | ✗ | ✗ | ✅ | ✅ |

> ⭐ **Lifecycle Workflows is not in P2 at all.** Not a reduced version — absent. This is the single
> most common licensing misunderstanding in identity governance, because entitlement management and
> access reviews *do* have P2 tiers and people reasonably assume LCW follows the pattern.

✅ **Limits with an ID Governance licence:** **50 workflows** total, **100 custom task extensions**.

**Licence counting** ✅ is by **users in scope plus the administrator**: a workflow that processes
400 new hires across a year needs **401**. ⭐ Note that leaver licences **can be reassigned** after
the workflow runs — 40 offboarded users free 40 licences.

---

## 4. Worked example — a leaver workflow that actually closes the door

```powershell
Connect-MgGraph -Scopes 'LifecycleWorkflows.ReadWrite.All'

$params = @{
  displayName = 'Leaver - last day'
  description = 'Disable, remove access, notify on the last day of employment'
  isEnabled   = $true
  executionConditions = @{
    '@odata.type' = '#microsoft.graph.identityGovernance.triggerAndScopeBasedConditions'
    scope = @{
      '@odata.type' = '#microsoft.graph.identityGovernance.ruleBasedSubjectSet'
      rule = "(department eq 'Sales')"
    }
    trigger = @{
      '@odata.type' = '#microsoft.graph.identityGovernance.timeBasedAttributeTrigger'
      timeBasedAttribute = 'employeeLeaveDateTime'
      offsetInDays = 0                      # ⭐ ON the leave date
    }
  }
  tasks = @(
    @{ displayName='Remove from all groups';  taskDefinitionId='b3a31406-2a15-4c9a-b25b-a658fa5f07fc'; continueOnError=$false; arguments=@() }
    @{ displayName='Remove all licenses';     taskDefinitionId='8fa97d28-3e52-4985-b3a9-a1126f9b8b4e'; continueOnError=$false; arguments=@() }
    @{ displayName='Disable user account';    taskDefinitionId='1dfdfcc7-52fa-4c2e-bf3a-e3919cc12950'; continueOnError=$false; arguments=@() }
  )
}
New-MgIdentityGovernanceLifecycleWorkflow -BodyParameter $params
```

⚠ **Task definition IDs are fixed GUIDs published by Microsoft** — look up the current list rather
than copying them from anywhere, including here.

**Then verify it actually ran, per user:**

```powershell
Get-MgIdentityGovernanceLifecycleWorkflowRun -LifecycleWorkflowId <id> |
  Select-Object StartedDateTime, ProcessingStatus, SuccessfulUsersCount,
                FailedUsersCount, TotalUsersCount | Sort-Object StartedDateTime -Descending
```

```
StartedDateTime       ProcessingStatus  SuccessfulUsersCount  FailedUsersCount  TotalUsersCount
--------------------  ----------------  --------------------  ----------------  ---------------
2026-08-09 03:00:12   completed                            7                 2                9   <-- ⚠
2026-08-08 03:00:09   completed                           12                 0               12
```

⭐ **`ProcessingStatus: completed` with `FailedUsersCount: 2` is the trap.** The *workflow* completed;
**two leavers were not offboarded.** A dashboard reading "completed" is exactly the kind of green
light that hides a security failure — drill into the per-user task report every time.

**The prerequisite nobody checks first:**

```powershell
Get-MgUser -All -Property UserPrincipalName,EmployeeHireDate,EmployeeLeaveDateTime |
  Where-Object { -not $_.EmployeeLeaveDateTime -and -not $_.EmployeeHireDate } |
  Measure-Object | Select-Object @{n='UsersWithNoLifecycleAttributes';e={$_.Count}}
```

⭐ **A perfect workflow over unpopulated attributes does nothing, silently.** The attributes must be
populated — by HR-driven provisioning, API-driven provisioning, or sync — **before** the workflow is
worth building. This is the same failure shape as an empty dynamic group.

---

## 5. What breaks

**Assuming P2 includes it.** §3 — it does not, at all.

**Unpopulated `employeeHireDate` / `employeeLeaveDateTime`.** §4 — silent no-op.

**Reading `completed` as success.** §4 — check `FailedUsersCount`.

**Disabling without revoking sessions.** Refresh tokens keep working.

**`continueOnError = true` on a leaver task.** The workflow reports success having skipped the
disable step.

**Building leaver automation before joiner automation.** Leaver is the security win; joiner is the
convenience. Most projects do them in the wrong order.

**Exceeding 50 workflows** through per-department duplication instead of scoping rules.

**No manual-trigger path** for immediate terminations, which never align with an HR date field.

---

## 6. Customer discovery questions

1. Is **ID Governance** licensed? *(If only P2, this conversation is about procurement.)*
2. Are `employeeHireDate` and `employeeLeaveDateTime` **populated**, and by what?
3. What happens today when someone leaves — a ticket, or automation?
4. How is an **immediate termination** handled outside the HR date?
5. Does the leaver process include **session revocation**, or only account disable?
6. Does anyone check `FailedUsersCount`, or just that the workflow ran?
7. How many workflows exist against the **50** limit?
8. Are movers handled at all, or only joiners and leavers?

---

## 7. Remember it

**Hook — "Trigger, scope, tasks."** An attribute plus an offset, a rule selecting users, an ordered
list of actions.

**Analogy — a payroll run, not a to-do list.** Offboarding as a ticket is a to-do list: it depends
on someone remembering, and during a redundancy round or a messy exit nobody does. **Lifecycle
Workflows makes it a payroll run** — it fires on a date already in the system, for everyone matching
the rule, whether or not anyone is watching. **And like payroll, "the run completed" is not the same
as "everyone got paid"** — which is exactly the `FailedUsersCount` trap.

**The one thing:** ⭐ **Lifecycle Workflows requires the ID Governance SKU and is entirely absent
from P2.** Entitlement management and access reviews have P2 tiers; LCW does not. Assuming it
follows the pattern is the most common licensing error in this area.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 8. Self-test

1. What are the three components of a workflow?
2. Which licence is required, and is there a P2 tier?
3. What are the workflow and custom-extension limits?
4. How are licences counted, and what is special about leaver licences?
5. A workflow shows `ProcessingStatus: completed`. Is everyone offboarded?
6. What silently prevents a correct workflow from doing anything?
7. Why is disabling the account insufficient for a leaver?
8. Why build joiner automation before leaver automation — or is that backwards?
9. How do you handle an immediate termination?

<details>
<summary>Answers</summary>

1. **Trigger** (time-based attribute + offset), **scope** (rule-based subject set), **tasks**
   (ordered actions).
2. **Microsoft Entra ID Governance.** **No P2 tier — it is absent from P2 entirely.**
3. **50 workflows**, **100 custom task extensions**.
4. **Users in scope plus the administrator.** ⭐ Leaver licences can be **reassigned** after the run.
5. **Not necessarily** — check **`FailedUsersCount`**. The workflow completing is not the same as
   every user being processed.
6. **Unpopulated `employeeHireDate` / `employeeLeaveDateTime`.** Silent no-op.
7. Existing **refresh tokens keep working** — you must also revoke sessions.
8. **Backwards.** Leaver is the **security** win; joiner is convenience. Do leaver first.
9. A **manual/on-demand trigger** — immediate terminations never align with an HR date field.

</details>

---

## 9. Evidence this topic needs

- **`lab/`** — build the §4 leaver workflow; run it on-demand against a test user; inspect the
  per-user task report. ✗ **Requires ID Governance.**
- **`break-fix/`** ⭐ — run a workflow against users with **unpopulated** lifecycle attributes and
  prove it silently does nothing. Then set `continueOnError = true` on the disable task and show a
  "successful" run that left the account enabled.
- **`security/`** — leaver workflow including **session revocation**; `FailedUsersCount` monitored
  and alerted; immediate-termination path documented.
- **`operations/`** — attribute population source confirmed; workflow count against the 50 limit.
- **`architecture-decisions/`** — ADR: leaver-first sequencing, and the ID Governance licensing
  decision with the capability gap that drives it.
- **`customer-use-cases/`** — §6 answered; a JML design as an engagement deliverable.

# Change Management (technical change control)

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary — two disciplines share this name.** This is **change control**: RFCs, approval,
> windows, backout plans, change success rate. **Organisational/adoption** change is
> [`../../75-architecture-and-consulting/change-management/`](../../75-architecture-and-consulting/change-management/).
> ⭐ **Ask which one someone means before answering.**

---

## 1. What it is

The process that governs modifications to a production system: how a change is proposed, assessed
for risk, approved, scheduled, executed, verified and — if necessary — backed out. In ITIL terms it
covers **standard**, **normal** and **emergency** changes.

⭐ **Change control exists to make change *safe*, not to make it *slow*. A process that only achieves
the second has failed.**

---

## 2. Why it exists

⭐ **Change is the leading cause of unplanned outages.** ⚠ The commonly quoted figure is that most
incidents follow a recent change; treat any specific percentage as unverified, but ⭐ **the
directional claim is uncontroversial and matches the evidence in your own activity log** — see
[`../incident-command/`](../incident-command/) §5.

| Without change control | ⭐ Consequence |
|---|---|
| No record of what changed | ⭐ **every incident starts from zero** |
| No backout plan | ⭐ rollback improvised under pressure |
| ⭐ Changes during peak | ⭐ maximum blast radius, minimum staffing |
| Approval by whoever is nearest | ⭐ nobody assessed the risk |
| ⭐ Emergency path used routinely | ⭐ **the process is bypassed and everyone knows it** |

⭐ **The last row is how change control dies.** When the normal path takes three weeks, every change
becomes an emergency — ⭐ **and a process that is routinely bypassed provides no safety at all while
still consuming everyone's time.** Fixing that means making the standard path *fast*, not policing
the emergency one harder.

---

## 3. How it works underneath — three classes, and the point of the classification

```
⭐ STANDARD    pre-approved, ⭐ low risk, ⭐ well-rehearsed, documented procedure
              ▸ e.g. adding a user to a group, ⭐ patching per the agreed baseline
              ▸ ⭐ NO approval needed each time - ⭐ approved ONCE as a class
              ▸ ⭐ THIS IS THE ESCAPE VALVE. Most changes should end up here.

   NORMAL     assessed and approved per change
              ▸ risk + impact + backout + window
              ▸ ⭐ approval PROPORTIONATE to risk - not one committee for everything

⭐ EMERGENCY   ⭐ approved retrospectively, ⭐ minimal ceremony, ⭐ FULL record after
              ▸ ⭐ restoring service is the priority
              ▸ ⭐ measure how often this path is used - ⭐ it is a health metric
```

⭐ **Growing the standard-change catalogue is the single highest-leverage improvement available in
change control.** Every routine change promoted to *standard* removes friction ⭐ **without removing
safety, because the safety came from the rehearsed procedure rather than from the approval meeting.**

⭐ **A high emergency-change rate is a diagnosis, not a discipline problem:** it says the normal path
is too slow for the pace of the business.

---

## 4. Worked example — an RFC that is actually useful

⭐ **The test: could someone else execute this and know whether it worked?**

```
RFC-2026-0219   Enable Conditional Access policy CA-004
Class  NORMAL      Risk  ⭐ HIGH (⭐ authentication path)      Requested D. Mwangi

⭐ WHAT CHANGES
  CA-004-Admin-PhishResistant-Prod: state report-only → enabled
  ⭐ Affects 9 administrators. ⭐ Break-glass accounts excluded (verified).

⭐ WHY NOW
  REQ-022; ⭐ 7 days report-only complete, ⭐ 0 unexpected blocks observed

⭐ RISK ASSESSMENT
  Likelihood  Low   ⭐ (report-only data shows no impact)
  Impact      ⭐ HIGH ⭐ (admin lockout would block all remediation)
  ⭐ Blast radius  9 users  ⭐ ← the number that decides the window

⭐ PRE-CHECKS  (⭐ must all pass immediately before - the checklist)
  ☐ Break-glass sign-in ⭐ tested TODAY, both accounts
  ☐ Both break-glass excluded from CA-004  ⭐ (script, zero rows)
  ☐ Report-only failures over 7 days = 0
  ☐ Named engineer available for 60 min after

⭐ BACKOUT  (⭐ tested in the test tenant on 2026-08-12)
  Set-MgIdentityConditionalAccessPolicy -Id <id> -State 'disabled'
  ⭐ Expected recovery time: < 5 min ⭐ (token cache may extend to 60 min)

⭐ VERIFICATION  (⭐ how we know it worked)
  1. Admin sign-in from a test client prompts for phishing-resistant method
  2. ⭐ Break-glass sign-in still succeeds        ← ⭐ the one people omit
  3. Zero unexpected failures in SigninLogs over 60 min

WINDOW  2026-08-19 19:00-20:00  ⭐ (low admin activity; ⭐ not month-end)
APPROVED  J. Okafor  2026-08-18
```

⭐ **"Backout tested in the test tenant on 2026-08-12" is the line that separates a real RFC from
paperwork.** ⭐ **An untested backout plan is a hypothesis**, and you will be testing it for the first
time during the incident it was written for.

⭐ **Verification step 2 — "break-glass sign-in still succeeds" — is the one almost everyone
omits.** You verified the change worked; ⭐ **you must also verify the recovery path still works
after it.** A change that succeeds *and* silently breaks recovery is the worst possible outcome,
because nothing reveals it until you need it.

⭐ **"Expected recovery time < 5 min, token cache may extend to 60 min"** is honest in a way most
RFCs are not: ⭐ **disabling a policy is instant, but existing tokens remain valid until they
expire** — so "rolled back" and "users are working again" are different moments. Knowing that
distinction is real Conditional Access competence.

---

## 5. Commands — measure the process, not just the changes

```powershell
# Every write in the last 30 days - ⭐ the actual change record, from evidence
Get-AzActivityLog -StartTime (Get-Date).AddDays(-30) -MaxRecord 1000 |
  Where-Object { $_.OperationName.Value -notmatch 'read|list' } |
  Group-Object { $_.Caller } | Select-Object Name, Count |
  Sort-Object Count -Descending | Select-Object -First 4
```

```
Name                            Count
automation@contoso.com            412
d.mwangi@contoso.com               88
⭐ github-actions-sp                 71
⭐ j.okafor@contoso.com              14
```

⭐ **Compare that list to the RFCs raised in the same period.** ⭐ **The gap between "changes made"
and "changes recorded" is the honest measure of whether change control is real** — and in most
organisations it is large.

**The four metrics worth tracking, and what each one tells you:**

| Metric | ⭐ What it diagnoses |
|---|---|
| ⭐ **Change success rate** | are changes well-prepared? ⭐ target > 95 % |
| ⭐ **Change-related incidents** | ⭐ is the risk assessment working? |
| ⭐ **Emergency change %** | ⭐ **is the normal path too slow?** |
| ⭐ **Lead time** | is the process an obstacle? |

⭐ **Two of these can look good while the system is unhealthy.** A 100 % success rate with a
six-week lead time means the process has stopped change rather than made it safe — ⭐ **which is why
lead time must be tracked next to success rate, never alone.**

---

## 6. When and where

| Environment | Control |
|---|---|
| Production, customer-facing | ⭐ **full** — RFC, approval, window, backout |
| ⭐ Production, standard change | ⭐ pre-approved class, ⭐ still recorded |
| Dev / test | ⭐ minimal — ⭐ **imposing production control here is pure friction** |
| ⭐ Infrastructure as code | ⭐ **the pull request IS the RFC** — review, approval, history, backout by revert |
| Emergency | act, ⭐ then document within 24 h |

⭐ **The IaC row is where this discipline is heading.** ⭐ **A reviewed, approved, versioned pull
request already contains everything an RFC does — what changed, who approved, and a backout (revert)
— with the enormous advantage that the record cannot drift from reality.** Recommending that a
customer's change record *be* their Git history is a modern, defensible answer.

⭐ **Change freezes are a real tool and must be defined in advance**: a retail customer freezing
production from mid-November to early January is prudent, not obstructive. ⭐ **What matters is that
the freeze dates and the exception path are agreed before the pressure arrives.**

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ Most changes are "emergency" | ⭐ normal path too slow | ⭐ grow the standard-change catalogue |
| Rollback fails when needed | ⭐ backout never tested | ⭐ test it in a test environment, date it |
| Incident, ⭐ nobody knows what changed | changes made outside the process | ⭐ §5 activity-log comparison |
| Approval is a rubber stamp | ⭐ approver cannot assess the risk | ⭐ approver must be technically competent |
| ⭐ Change succeeded, recovery broken | ⭐ recovery path not verified after | ⭐ verification step 2 |
| Process resented and bypassed | ⭐ same ceremony for every change | ⭐ proportionality |
| Freeze argued about in December | not agreed in advance | ⭐ publish freeze dates in January |

⭐ **"Approval is a rubber stamp" deserves naming.** ⭐ **An approver who cannot assess the risk adds
delay without adding safety** — the worst combination available. If the only competent reviewer is
the person making the change, ⭐ **say so and design peer review instead of hierarchical approval.**

---

## 8. Customer discovery questions

1. ⭐ **"What proportion of your changes go through the emergency path?"**
2. "How long does a normal change take from request to execution?"
3. ⭐ **"Do you have standard pre-approved changes, and how many?"**
4. "Has a backout plan ever been tested before it was needed?"
5. ⭐ **"Who approves, and can they technically assess the risk?"**
6. "Do you have change freeze periods, and are the dates published?"
7. ⭐ **"If I compared your activity log to your change records, would they match?"**

---

## 9. Remember it

**Hook — `S N E`: Standard (pre-approved), Normal (assessed), Emergency (retrospective).**
⭐ **Health = a large Standard catalogue and a small Emergency percentage.**

**Analogy — airport security lanes.** ⭐ **Pre-check for known-good routine travellers (standard
change), the normal lane with proportionate screening (normal change), and a marshalled escort for
genuine emergencies — logged afterwards (emergency change).** The analogy predicts the failure
precisely: ⭐ **if the normal lane takes three hours, everyone claims to be an emergency, and
security stops working while still making everyone late.** ⭐ **The fix is a bigger pre-check
programme, not more guards on the emergency door.**

**The one line:** ⭐ **Make the safe path the fast path — and an untested backout plan is a
hypothesis.**

---

## 10. Self-test

1. Which discipline is this, and what is the other?
   → ⭐ Technical change control; the other is organisational/adoption change.
2. Highest-leverage improvement in most change processes?
   → ⭐ Grow the standard (pre-approved) change catalogue.
3. What does a high emergency-change rate diagnose?
   → ⭐ The normal path is too slow — a process problem, not a discipline problem.
4. Why track lead time alongside change success rate?
   → ⭐ A perfect success rate with a six-week lead time means change has stopped, not become safe.
5. Which verification step is most often omitted?
   → ⭐ Confirming the **recovery path** still works after the change.
6. Why can rollback of a CA policy be "instant" and yet users stay broken?
   → ⭐ Existing tokens remain valid until they expire; disabling the policy does not revoke them.
7. In an IaC estate, what is the RFC?
   → ⭐ The pull request — reviewed, approved, versioned, revertible.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | one complete RFC in the §4 format, executed and verified |
| `operations` | ⭐ the four metrics for one month, ⭐ including emergency percentage |
| `break-fix` | ⭐ one backout actually performed, with the elapsed time |
| `security` | evidence the recovery path was verified after a change |
| `architecture-decisions` | ⭐ the standard-change catalogue, and what was promoted into it |

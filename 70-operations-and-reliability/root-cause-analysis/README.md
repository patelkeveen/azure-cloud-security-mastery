# Root Cause Analysis

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** this is the **retrospective** — what happened and what changes. The **live
> diagnostic technique** is
> [`../../00-foundations/troubleshooting-method/`](../../00-foundations/troubleshooting-method/);
> running the incident is [`../incident-command/`](../incident-command/).

---

## 1. What it is

The structured review after an incident: an agreed timeline, the contributing factors, and a small
number of **tracked actions with owners and dates**. Conducted **blamelessly**, because the
alternative reliably produces less information.

⭐ **The output is not a document. It is a set of changes that make the next incident less likely or
less severe.** A postmortem with no tracked actions was theatre.

---

## 2. Why it exists

⭐ **Without it, organisations pay for the same outage repeatedly and call it bad luck.** What
actually goes wrong:

| Without a real RCA | ⭐ Consequence |
|---|---|
| ⭐ "Human error" recorded as the cause | ⭐ **nothing changes** — the next person will do the same |
| Blame attached | ⭐ people stop reporting near-misses; ⭐ **you go blind** |
| Actions with no owner | ⭐ zero completed |
| ⭐ Single "root" cause found | the other three factors remain live |
| Written but never read | recurrence |

⭐ **The second row is the expensive one, and it is invisible.** In a blame culture, the incidents
you *hear* about are only the ones too big to hide — ⭐ **and the near-misses, which are free
information, disappear entirely.**

---

## 3. How it works underneath — why "the root cause" is usually the wrong frame

⭐ **Complex systems do not fail from one cause. They fail when several conditions coincide**, and
each condition was individually tolerable.

```
⭐ FIVE WHYS  → a single chain. Fast, but it finds ONE path and stops.

   sign-ins failed
     └─ why? CA policy blocked them
         └─ why? policy enabled without report-only
             └─ why? engineer under deadline pressure
                 └─ why? ⭐ "human error"   ← ⭐ DEAD END. Nothing to fix.

⭐ CONTRIBUTING FACTORS → a graph. Slower, and it finds what you can change.

   sign-ins failed
     ├─ ⭐ policy enabled directly, no report-only     → ⭐ CHECKLIST GAP
     ├─ ⭐ change made outside the change window       → ⭐ PROCESS GAP
     ├─ ⭐ no alert on CA policy modification          → ⭐ DETECTION GAP
     ├─ ⭐ break-glass untested → recovery took 22 min → ⭐ READINESS GAP
     └─ ⭐ deadline pressure from an audit date        → ⭐ ORGANISATIONAL
```

⭐ **Both analyses start identically; only the second yields four fixable things.** ⭐ **Five Whys is
useful for a simple mechanical fault and actively misleading for a sociotechnical one** — knowing
when to abandon it is the actual skill.

⭐ **"Human error" is where analysis begins, never where it ends.** The productive question is not
*"why did they do that?"* but ⭐ ***"why was that a reasonable thing to do at the time, given what
they could see?"*** — because the answer names a system property you can change.

---

## 4. Worked example — the numbers a postmortem must contain

⭐ **Timeline first, and the three intervals below are what turn a story into a measurement.**

```
POSTMORTEM  INC-2026-0814  Sign-in failures
Severity 1 · ⭐ User impact: ~30 % of sign-ins, 34 minutes

TIMELINE (UTC)
09:07  CA policy "Require compliant device" enabled directly     ⭐ the change
09:12  ⭐ First user-reported failure                              ⭐ IMPACT BEGINS
09:19  Monitoring alert fires (sign-in failure rate)             ⭐ DETECTED
09:21  Incident declared, IC assumed
09:28  Hypothesis: recent CA change (⭐ from the activity log)
09:33  ⭐ Break-glass sign-in attempted - ⭐ FAILED, password stale
09:41  Second break-glass account succeeded
09:46  Policy set to report-only                                 ⭐ MITIGATED
09:52  Sign-in success rate normal                               ⭐ RESOLVED

⭐ THE THREE NUMBERS
  ⭐ TTD  time to detect    09:12 → 09:19   =  ⭐ 7 min
  ⭐ TTM  time to mitigate  09:19 → 09:46   =  ⭐ 27 min
      TTR  total impact     09:12 → 09:52   =  ⭐ 40 min
  ⭐ Error budget consumed: 40 of 43.2 monthly minutes = ⭐ 93 %
```

⭐ **Detection took 7 minutes and mitigation took 27.** ⭐ **That ratio tells you where to invest:
detection is fine; mitigation is the problem** — and within mitigation, ⭐ **8 of those 27 minutes
were spent on a break-glass account that did not work.**

⭐ **Expressing impact as 93 % of the monthly error budget** ([`../slis-slos-and-slas/`](../slis-slos-and-slas/))
converts *"a bad morning"* into a number that triggers an agreed policy. ⭐ **That is the sentence
that gets reliability work prioritised.**

**Actions — ⭐ the only part that changes anything:**

```
⭐ ACTIONS  (⭐ every one: owner, date, tracked in the normal work system)

A1  ⭐ Add "policy must pass 7 days report-only" to the CA checklist
    Owner D. Mwangi   Due 2026-08-21   ⭐ Prevents recurrence
A2  ⭐ Alert on CA policy modification (activity log alert)
    Owner L. Petrov   Due 2026-08-28   ⭐ Reduces TTD
A3  ⭐ QUARTERLY break-glass sign-in test, calendared with an owner
    Owner J. Okafor   Due 2026-09-01   ⭐ Reduces TTM  ← ⭐ highest value
A4  Document the CA rollback command in the runbook
    Owner D. Mwangi   Due 2026-08-21   Reduces TTM

⭐ NOT AN ACTION: "be more careful"  ⭐ "remind the team"  ⭐ "add training"
   ⭐ - none of these are verifiable, and none survive staff turnover
```

⭐ **A3 is the highest-value action and it came from a *failure during the response*, not from the
original cause.** ⭐ **The incident revealed a second, latent failure — untested break-glass — that
would have been worse in a real lockout.** Postmortems routinely surface these, and they are often
worth more than the headline finding.

⭐ **Tag each action with which number it improves — TTD or TTM.** Actions that reduce nothing
measurable are usually the "be more careful" family in disguise.

---

## 5. Commands — reconstruct the timeline from evidence, not memory

```powershell
# ⭐ The change that started it
Get-MgAuditLogDirectoryAudit `
  -Filter "activityDateTime ge 2026-08-14T09:00:00Z and activityDateTime le 2026-08-14T10:00:00Z" |
  Select-Object ActivityDateTime, ActivityDisplayName,
    @{n='By';e={$_.InitiatedBy.User.UserPrincipalName}}
```

```
ActivityDateTime     ActivityDisplayName               By
14/08/2026 09:07:12  Update conditional access policy  j.okafor@contoso.com
14/08/2026 09:46:03  Update conditional access policy  j.okafor@contoso.com
```

```kusto
// ⭐ Impact, measured - this is the "30 % of sign-ins" claim, evidenced
SigninLogs
| where TimeGenerated between (datetime(2026-08-14 09:00) .. datetime(2026-08-14 10:00))
| summarize Total = count(), Failed = countif(ResultType != 0) by bin(TimeGenerated, 5m)
| extend FailPct = round(100.0 * Failed / Total, 1)
```

```
TimeGenerated       Total  Failed  FailPct
14/08/2026 09:05      412       8      1.9
14/08/2026 09:10      388     119     30.7   ⭐ impact begins
14/08/2026 09:45      401     104     25.9
14/08/2026 09:50      396       6      1.5   ⭐ resolved
```

⭐ **The postmortem now states "30.7 %" with a query behind it**, rather than "a lot of users". ⭐ **A
timeline built from logs is defensible; one built from memory is contested in the meeting**, and the
meeting then discusses the timeline instead of the fixes.

---

## 6. When and where

| Trigger | Depth |
|---|---|
| Any Sev1 | ⭐ **full written postmortem, ⭐ within 5 working days** |
| Sev2 with customer impact | short form |
| ⭐ **Near miss** | ⭐ **full — and this is the cheapest learning available** |
| Repeat of a previous incident | ⭐ review the **previous** actions: were they completed? |
| Sev3 / single user | ⭐ ticket notes are enough |

⭐ **Write it within five days.** Memory degrades fast, and ⭐ **the organisational appetite to act
decays faster than the memory does** — a postmortem delivered three weeks later lands in a room that
has moved on.

⭐ **Near-miss reviews are the highest-return activity in this whole domain**, because you get the
learning without the outage. An organisation that only reviews actual failures is learning at the
most expensive possible price.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| Same incident recurs | ⭐ actions never completed | ⭐ track in the normal backlog, not a doc |
| ⭐ "Human error" as the conclusion | Five Whys ran to a dead end | ⭐ contributing-factor graph |
| Meeting becomes a trial | blame culture | ⭐ blameless framing, stated at the start |
| Timeline disputed | reconstructed from memory | ⭐ build it from logs |
| ⭐ Near-misses never reviewed | ⭐ only outages trigger a review | ⭐ make near-miss a trigger |
| ⭐ Actions are "be more careful" | no verifiability test | ⭐ each action names TTD or TTM |
| Nobody reads it | 12 pages of narrative | ⭐ timeline, factors, actions — that is all |

⭐ **"Blameless" is not the same as "consequence-free", and the distinction matters.** ⭐ **Blameless
means the analysis assumes people acted reasonably given what they could see** — because that
assumption is what produces accurate information. ⭐ **A system that punishes honest reporting gets
dishonest reporting**, and then you are operating blind.

---

## 8. Customer discovery questions

1. ⭐ **"What were the actions from your last postmortem, and are they done?"**
2. "Do you measure time-to-detect separately from time-to-mitigate?"
3. ⭐ **"Do you review near-misses, or only outages?"**
4. "Who attends, and is the person who made the change in the room?"
5. ⭐ **"Has the same incident happened twice?"**
6. "Where do actions get tracked?"
7. ⭐ **"When did an incident last change a checklist or a runbook?"**

---

## 9. Remember it

**Hook — `T T A`: Timeline, TTD/TTM, Actions.** ⭐ Three things; ⭐ **only the third one changes
anything.**

**Analogy — an air accident investigation, not a court.** ⭐ **The investigators are legally
separated from the prosecutors, precisely because the goal is information rather than punishment —
and the industry accepted long ago that you cannot have both.** The analogy predicts everything:
⭐ **the timeline is built from the recorders rather than testimony, "pilot error" is the start of
the enquiry rather than its finding, near-misses are reported voluntarily in their thousands, and
the output is an airworthiness directive with a deadline — not a memo asking crews to be careful.**

**The one line:** ⭐ **Contributing factors, not a root cause — and an action with no owner and no
date is not an action.**

---

## 10. Self-test

1. Why is "the root cause" often the wrong frame?
   → ⭐ Complex systems fail when several individually tolerable conditions coincide.
2. When does Five Whys mislead?
   → ⭐ On sociotechnical failures — it finds one chain and terminates at "human error".
3. Better question than "why did they do that?"
   → ⭐ "Why was that reasonable at the time, given what they could see?"
4. Define TTD and TTM, and why separate them?
   → ⭐ Detect vs mitigate; the ratio tells you where to invest.
5. Why express impact as error budget consumed?
   → ⭐ It converts a bad morning into a number that triggers an agreed policy.
6. What makes an action valid?
   → ⭐ An owner, a date, tracked in the normal backlog, and it reduces TTD or TTM.
7. Why review near-misses?
   → ⭐ Same learning, no outage — the cheapest information available.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | a timeline reconstructed from logs, with the queries used |
| `operations` | ⭐ TTD/TTM calculated for one real incident |
| `break-fix` | ⭐ the contributing-factor graph, showing ≥3 fixable factors |
| `architecture-decisions` | the action list with owners and dates, and evidence of completion |
| `customer-use-cases` | ⭐ one near-miss reviewed as if it had been an outage |

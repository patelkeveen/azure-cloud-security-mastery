# Incident Command

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** the same role structure as
> [`../../75-architecture-and-consulting/cutover-playbooks/`](../../75-architecture-and-consulting/cutover-playbooks/),
> but for **unplanned** events — no schedule, unknown cause, unknown duration.
> ⭐ **That difference changes everything about how the roles behave.**

---

## 1. What it is

A defined command structure for running an outage: one **Incident Commander** who decides and does
not fix, responders who investigate, a **Communications Lead** who talks to everyone outside the
room, and a **Scribe** who timestamps. Adapted from emergency services' Incident Command System.

⭐ **Its purpose is not to fix faster. It is to stop the *coordination* from becoming the outage.**

---

## 2. Why it exists

⭐ **Past about four people, an incident fails on communication rather than on technical difficulty.**
The recognisable symptoms:

| Symptom | ⭐ Underlying cause |
|---|---|
| Three people restart the same service | ⭐ no one owns the action list |
| ⭐ Two conflicting fixes applied at once | ⭐ no single decision-maker |
| ⭐ Exec joins and asks for a status update | ⭐ **the person fixing it stops to answer** |
| Nobody knows what has been tried | no scribe |
| ⭐ Fix applied that made it worse | ⭐ no change discipline under pressure |
| Postmortem is guesswork | ⭐ **no timeline exists** |

⭐ **The third row is the most expensive and the least discussed.** ⭐ **Every executive status
request that reaches a responder directly costs 10–15 minutes of the only person who can fix the
problem** — and a Communications Lead exists precisely to absorb that.

---

## 3. How it works underneath

```
                    ⭐ INCIDENT COMMANDER
                    ⭐ decides · prioritises · ⭐ DOES NOT TYPE
                    ⭐ owns the action list and the severity
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ⭐ OPS LEAD           ⭐ COMMS LEAD           ⭐ SCRIBE
   investigates,         ⭐ the ONLY channel     ⭐ timestamps every
   proposes actions,     to execs, customers,    action, decision
   ⭐ executes only        status page             and observation
   what the IC agrees    ⭐ fixed cadence
        │
   responders (n)
```

⭐ **"The Incident Commander does not type" is the rule everyone breaks and everyone regrets.** The
moment the IC starts debugging, ⭐ **they lose the overview exactly when the incident needs one** —
and nobody else is empowered to notice the team has been down a dead end for forty minutes.

⭐ **On a small team, one person can hold two roles — but never IC and Ops Lead.** That is the same
constraint as Lead-and-Executor in a cutover.

⭐ **The IC role is not seniority-based.** ⭐ **The most senior engineer is usually the *worst* IC**,
because they are the person you most want debugging. IC is a role, assumed and handed over
explicitly: *"I am taking incident command"* — said out loud, recorded by the scribe.

---

## 4. Worked example — the first fifteen minutes

⭐ **This is the part that decides how the next three hours go.**

```
T+0    ⭐ Alert fires. Responder acknowledges.
T+2    ⭐ Responder DECLARES an incident rather than investigating alone.
       ⭐ "Declaring an incident" is a low-cost action. ⭐ Under-declaring is
          the expensive mistake, not over-declaring.
T+3    ⭐ IC assumed, OUT LOUD:  "I'm IC for this. D. Mwangi on ops,
          S. Roy on comms, A. Bose scribing."
T+5    ⭐ IC sets INITIAL SEVERITY and states the IMPACT in user terms:
       ⭐ "Sev1. Sign-in failing for roughly 30 % of users since 09:12."
          ⭐ NOT "the token service is throwing 500s"  ← ⭐ that is a symptom,
          and executives cannot act on it
T+7    ⭐ Comms sends first update - ⭐ BEFORE the cause is known.
       ⭐ "We are aware, investigating, next update 09:30."
T+10   IC asks for hypotheses, ⭐ picks ONE to test, assigns it.
       ⭐ "What changed?" is always the first question - see §5.
T+15   ⭐ First scheduled update, ⭐ whether or not anything has changed.
```

⭐ **T+7 is counter-intuitive and non-negotiable: communicate before you understand.** ⭐ **Silence is
interpreted as "nobody is looking at it"**, which generates precisely the executive escalations that
slow the fix. A message saying "we know, we are on it, next update at 09:30" costs thirty seconds
and buys twenty minutes of quiet.

⭐ **Impact in user terms, not component terms.** *"30 % of sign-ins failing"* lets a business decide
whether to invoke a manual process; ⭐ *"the token service is 500ing"* tells them nothing they can
act on.

**Severity, defined in advance — ⭐ the definitions must exist before the incident:**

| Sev | Definition | ⭐ Response |
|---|---|---|
| **1** | ⭐ Service unusable for many users, ⭐ or an active security compromise | ⭐ page immediately, 24×7, IC required |
| **2** | Degraded, or a workaround exists | page in hours |
| **3** | Minor / single user | ticket |

⭐ **An active security incident is Sev1 regardless of user impact.** Data exfiltration is silent and
degrades nothing — ⭐ **a severity scale based purely on availability will systematically
under-prioritise the worst events**, which is a genuine design flaw in most homegrown scales.

---

## 5. Commands — "what changed?" answered in one query

⭐ **Most incidents are caused by a change** ⚠ (widely cited as the majority; treat the exact figure
as unverified). ⭐ **So the first diagnostic is not "what is broken" but "what changed in the last
few hours".**

```powershell
Get-AzActivityLog -StartTime (Get-Date).AddHours(-6) -MaxRecord 200 |
  Where-Object { $_.OperationName.Value -notmatch 'read|list' -and
                 $_.Status.Value -eq 'Succeeded' } |
  Select-Object EventTimestamp, Caller,
                @{n='Op';e={$_.OperationName.LocalizedValue}}, ResourceId |
  Sort-Object EventTimestamp -Descending | Select-Object -First 5
```

```
EventTimestamp       Caller               Op                          ResourceId
14/08/2026 09:08:41  d.mwangi@contoso.com Update network security group nsg-app-prod
14/08/2026 08:55:02  automation@contoso   Create or Update deployment  rg-app-prod
```

⭐ **An NSG updated at 09:08, four minutes before sign-in failures began at 09:12.** ⭐ **That is not
proof, but it is the first hypothesis and it costs one query** — and the temporal correlation alone
reorders the entire investigation.

**Tenant-side, for identity incidents:**

```powershell
Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge 2026-08-14T06:00:00Z" -Top 5 |
  Select-Object ActivityDateTime, ActivityDisplayName,
    @{n='By';e={$_.InitiatedBy.User.UserPrincipalName}}, Result
```

```
ActivityDateTime     ActivityDisplayName              By                    Result
14/08/2026 09:07:12  Update conditional access policy j.okafor@contoso.com  success
```

⭐ **A Conditional Access policy updated five minutes before sign-ins started failing is very
probably your incident** — and this exact query is why the *"watch first / report-only"* discipline
in [`../../30-identity-and-nhi/conditional-access/`](../../30-identity-and-nhi/conditional-access/)
exists.

⭐ **Note both queries filter out reads.** Reads are noise; ⭐ **only writes change behaviour.**

---

## 6. When and where

| Situation | Structure |
|---|---|
| One responder, obvious cause | ⭐ no ceremony — ⭐ **do not impose process on a five-minute fix** |
| ⭐ >2 responders, or >30 minutes | ⭐ declare, assign an IC |
| Any Sev1 | ⭐ full structure, always |
| ⭐ Security incident | ⭐ full structure + ⭐ **evidence preservation before remediation** |
| ⭐ Multi-hour incident | ⭐ **plan IC handover** — see below |

⭐ **Security incidents invert one instinct: do not reboot, do not delete, do not "clean up" first.**
⭐ **Volatile evidence — sessions, tokens, memory, sign-in logs — is destroyed by the reflex to fix**,
and it is the evidence the investigation needs. Contain, preserve, then remediate.

⭐ **Incidents longer than about four hours need an explicit IC handover**, spoken and recorded:
*"handing IC to L. Petrov; current state is X, we have tried Y, the open action is Z."* ⭐ **Fatigued
ICs make the worst decisions of an incident**, and the handover is a control, not an admission.

---

## 7. What breaks

| Symptom | Cause | Fix |
|---|---|---|
| ⭐ IC is also debugging | role collapsed under pressure | ⭐ IC does not type |
| Conflicting fixes applied | ⭐ no single decision-maker | ⭐ all actions approved by IC |
| Exec escalations mid-incident | no comms cadence | ⭐ fixed updates, ⭐ even with no news |
| ⭐ Postmortem is guesswork | no scribe | ⭐ appoint one at T+3 |
| ⭐ "It's fixed" then it isn't | ⭐ no verification before all-clear | ⭐ verify like a user, then stand down |
| Security evidence destroyed | remediation before preservation | ⭐ contain → preserve → remediate |
| Nobody declared | ⭐ fear of over-reacting | ⭐ declaring is cheap; ⭐ reward it |

⭐ **"Nobody declared" is a *culture* failure with a technical-looking symptom.** If declaring an
incident is treated as an admission of failure, people investigate alone for ninety minutes first —
⭐ **and the organisation loses ninety minutes it will never get back.** The fix is leadership
behaviour: ⭐ **thank people for declaring, especially when it turns out to be nothing.**

---

## 8. Customer discovery questions

1. ⭐ **"Who is the Incident Commander for a Sev1 at 03:00, by name?"**
2. "Are severity levels written down, and does everyone agree on them?"
3. ⭐ **"During your last incident, who talked to the executives?"**
4. "Do you keep a timeline during the incident, or reconstruct it after?"
5. ⭐ **"Is a security incident automatically Sev1?"**
6. "What is your status-page or customer-comms cadence?"
7. ⭐ **"When did you last practise this?"** — [`../chaos-and-failure-injection/`](../chaos-and-failure-injection/)

---

## 9. Remember it

**Hook — `I O C S`: Incident commander, Ops, Comms, Scribe.** ⭐ **The IC decides and does not type;
the Scribe is what makes the postmortem possible.**

**Analogy — a fire ground, not a fire.** ⭐ **The incident commander stands outside the building with
a radio and a board. They are not the best firefighter present — that person is inside, which is
exactly why they cannot also be running the incident.** The analogy predicts every rule here:
⭐ **one commander, actions approved before they are taken, a fixed cadence of updates to the people
outside the cordon, and a written log that the subsequent investigation depends on.**

**The one line:** ⭐ **Declare early, name an IC who does not type, communicate before you understand
— and ask "what changed?" first.**

---

## 10. Self-test

1. Why must the IC not perform the fix?
   → ⭐ They lose the overview precisely when the incident needs one.
2. Why is the most senior engineer usually the wrong IC?
   → ⭐ They are the person you most want debugging.
3. Why communicate before the cause is known?
   → ⭐ Silence reads as inaction and generates escalations that slow the fix.
4. State impact correctly: component or user terms?
   → ⭐ User terms — "30 % of sign-ins failing", not "the token service is 500ing".
5. Why is a security incident Sev1 regardless of availability impact?
   → ⭐ Exfiltration is silent; an availability-only scale under-prioritises the worst events.
6. First diagnostic question in most incidents?
   → ⭐ "What changed?" — activity log and directory audit, writes only.
7. Order of operations in a security incident?
   → ⭐ Contain, preserve evidence, then remediate.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | the "what changed" queries run against a real tenant |
| `operations` | ⭐ a scribe's timeline from a real or simulated incident |
| `security` | the evidence-preservation step, performed before remediation |
| `break-fix` | one incident where the change log produced the hypothesis |
| `architecture-decisions` | ⭐ the severity definitions, agreed before they were needed |

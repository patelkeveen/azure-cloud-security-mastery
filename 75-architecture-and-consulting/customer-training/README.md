# Customer Training

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⭐ **Training is not a session. It is a demonstrated capability, verified before you leave.**
> Pairs with [`../handover/`](../handover/), [`../sop-and-runbooks/`](../sop-and-runbooks/) and
> [`../change-management/`](../change-management/).

---

## 1. What it is

The structured transfer of operating capability from you to the customer's people: not a
walkthrough of what you built, but ⭐ **evidence that named individuals can perform named tasks
unaided.** It has personas, objectives, materials, and — the part that is usually missing — a
verification.

---

## 2. Why it exists

⭐ **The default failure is a two-hour screen-share, a recording nobody watches, and a support call
in week three.** What goes wrong is specific:

| Common approach | Why it fails |
|---|---|
| ⭐ One session, everyone invited | ⭐ admins and end users need **opposite** content |
| Demo of what you built | ⭐ shows *your* competence, not theirs |
| Recording sent afterwards | ⭐ **watched by almost nobody** — and never at 03:00 |
| ⭐ "Any questions?" as the check | ⭐ silence measured as understanding |
| Training before go-live only | ⭐ no reinforcement; ⭐ week-two decay |

⭐ **"Any questions?" is not a verification.** The person who most needs help is the least likely to
ask in front of colleagues, and the one who does ask is usually already competent.

---

## 3. How it works underneath — four audiences, four objectives

⭐ **Splitting by audience is the whole method. One deck for everyone serves nobody.**

```
① END USERS         ⭐ what changes for ME, and what do I do
                      ⭐ 10 minutes max. Video or one page. NOT a meeting
                      objective: complete the new sign-in unaided

② SERVICE DESK      ⭐ the top 5 tickets this change will generate,
                      and the exact response to each
                      ⭐ objective: resolve tier-1 without escalating

③ ⭐ ADMINISTRATORS  operate, monitor, ⭐ and RECOVER
                      ⭐ objective: perform each SOP unaided, observed

④ ⭐ SPONSOR/MANAGER  ⭐ what to look at monthly, and what "good" looks like
                      objective: ⭐ notice decay without being told
```

⭐ **Audience ② is the one that determines whether your phone rings after handover.** ⭐ **Train the
service desk on the tickets your change will create — before it creates them** — and you convert
your escalations into their routine work. Predicting those five tickets is a genuine skill: they
come straight from the friction table in [`../change-management/`](../change-management/) §4.

⭐ **Audience ④ is the one nobody trains, and it is why controls decay.** A manager who has never
been shown what the adoption number should look like cannot notice it falling.

---

## 4. Worked example — the competency matrix

⭐ **The deliverable is not "training was delivered". It is this table, completed with names, dates
and an observer.**

```
TRAINING PLAN   Privileged access (PIM) - administrator competency

TASK                              WHO      METHOD        ⭐ VERIFIED BY        DATE
──────────────────────────────────────────────────────────────────────────────────
Activate an eligible role         D.M      ⭐ do it live   ⭐ observed, unaided  08-14
Approve another user's request    D.M,L.P  do it live    ⭐ observed           08-14
⭐ Break-glass sign-in + reseal    D.M      ⭐ FULL REHEARSE ⭐ observed +        08-15
                                                          ⭐ new seal photo'd
Read the PIM audit log for        L.P      ⭐ find a       ⭐ found it unaided   08-15
  "who activated what, when"               ⭐ PLANTED event
Respond to risky sign-in (RB-03)  L.P      ⭐ TABLETOP     ⭐ followed runbook,  08-16
                                            ⭐ simulated     ⭐ found the rule
Quarterly access review actioning A.B      do it live    ⭐ observed           08-16
──────────────────────────────────────────────────────────────────────────────────
⭐ NOT YET COMPETENT: none.  ⭐ Gaps here block handover sign-off.
```

⭐ **"Verified by: observed, unaided" is the entire point of the document.** Watching someone do it
while you narrate proves nothing; ⭐ **sitting silently while they do it, and resisting the urge to
help, is the actual test.** The discomfort of that silence is the measurement.

⭐ **The planted-event technique is worth stealing.** Before the session, activate a role yourself
under a distinctive account. Then ask the trainee to find *who activated what and when*. ⭐ **They
cannot pass by nodding** — either they navigate to the audit log and find your event, or they
cannot, and now you both know.

⭐ **The break-glass rehearsal is non-negotiable and is the row most often skipped**, because it
requires breaking a seal and re-sealing afterwards. ⭐ **An untested recovery procedure is not a
recovery procedure** — the same rule as
[`../configuration-checklists/`](../configuration-checklists/) §4 item 3.

---

## 5. Commands — let them run it, and watch

⭐ **Hand the keyboard over. The best training artifact is a script the customer runs themselves,
whose output they can interpret.**

```powershell
# Give them this; ask them to explain the output, unaided
Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All |
  Where-Object AssignmentType -eq 'Activated' |
  Select-Object PrincipalId, RoleDefinitionId, StartDateTime, EndDateTime
```

```
PrincipalId   RoleDefinitionId  StartDateTime         EndDateTime
3f9a1c72-...  62e90394-...      2026-08-14T09:12:00Z  2026-08-14T13:12:00Z
```

⭐ **Then ask three questions and listen for the reasoning, not the answer:**

1. *"Who is `3f9a1c72`?"* — ⭐ can they resolve a GUID to a person? (`Get-MgUser -UserId`)
2. *"Which role is that?"* — do they recognise Global Administrator's template ID, or know how to look it up?
3. ⭐ ***"Why does it end at 13:12?"*** — ⭐ **do they understand that activation is time-bound?**

⭐ **Question 3 is the one that separates understanding from clicking.** Someone who cannot explain
the four-hour expiry does not yet understand what PIM *is*, however confidently they used the
portal.

**Leave them a self-check they can run monthly without you:**

```powershell
.\Invoke-HealthCheck.ps1        # ⭐ handed over as part of the SOP pack
```

```
[PASS] Break-glass accounts: 2 found, both excluded from 6 enabled CA policies
[PASS] Global Administrators: 2 permanent (break-glass), 7 eligible
[WARN] Access review "Guest quarterly": completed 2026-05-02 - ⭐ 108 days ago
```

⭐ **A script that prints its own warnings outlives any training session**, and it is the artifact
that makes audience ④ possible: a manager can read `[WARN]` without knowing PowerShell. ⭐ **This is
the same design as [`../../SC-300-SPRINT/Invoke-SprintCheck.ps1`](../../SC-300-SPRINT/Invoke-SprintCheck.ps1)
— every failure prints its own fix, so the reader never needs to ask anyone.**

---

## 6. When and where

| Audience | Format | Duration |
|---|---|---|
| End users | ⭐ 90-second video + one page | ⭐ never a meeting |
| Service desk | ⭐ top-5 tickets + tabletop | 60 min |
| Administrators | ⭐ hands-on, observed, ⭐ in **their** tenant | ⭐ 2 x 90 min, split over days |
| Sponsor / manager | ⭐ the monthly dashboard walk | 30 min |

⭐ **Split administrator training across two days.** Everything taught in one session is forgotten
by the following week; ⭐ **a gap with a task in between converts recognition into recall** — the same
spacing principle the repo's own [`../../RETENTION.md`](../../RETENTION.md) is built on.

⭐ **Train in the customer's own tenant, never a demo environment.** Their group names, their
policies, their approvers. A demo tenant teaches the product; ⭐ **their tenant teaches their system**,
and only one of those is what they will operate on a bad day.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Calls continue after handover | ⭐ service desk not trained on **their** tickets | audience ② |
| "We were never shown that" | no competency matrix | ⭐ §4, signed |
| Trained person leaves | ⭐ single point of knowledge | ⭐ **two people per task, always** |
| ⭐ Recovery fails when needed | break-glass never rehearsed | ⭐ the row people skip |
| Everything forgotten | one long session | ⭐ split with a gap and a task |
| Control decays unnoticed | ⭐ manager never trained | audience ④ + the health-check script |
| Demo-tenant training | convenience | ⭐ train in their tenant |

⭐ **"Two people per task, always"** — because the single trained administrator will be on leave
during the first real incident. This is the training equivalent of the two-break-glass-accounts rule,
and it has the same justification: ⭐ **a control with one point of failure is not a control.**

---

## 8. Customer discovery questions

1. ⭐ **"Who exactly will operate this, and is there a second person?"**
2. "What is your service desk's current skill level with Entra?"
3. ⭐ **"How do your people prefer to learn — reading, video, or hands-on?"**
4. "Is there a learning platform we should publish materials to?"
5. ⭐ **"Who reviews the security posture monthly, and what do they look at today?"**
6. "What happened last time a system was handed over — did it work?"
7. ⭐ **"May we rehearse break-glass together, including resealing?"**

---

## 9. Remember it

**Hook — `U D A S`: Users, Desk, Admins, Sponsor.** Four audiences, four objectives; ⭐ **the Desk
decides whether your phone rings, the Sponsor decides whether the control survives.**

**Analogy — a driving test, not a driving lesson.** ⭐ **The lesson is delivery; the test is the
deliverable — and the examiner sits silently while you do it, because the whole point is that no one
is helping.** The analogy predicts the method: ⭐ **you test on real roads, not a car park (their
tenant), you test the emergency stop even though it is inconvenient (break-glass rehearsal), and
nobody passes by nodding along.**

**The one line:** ⭐ **Sit on your hands and watch them do it — training is verified capability, not
a delivered session.**

---

## 10. Self-test

1. Why split training by audience?
   → ⭐ End users and administrators need opposite content; one deck serves nobody.
2. Which audience determines whether you get called after handover?
   → ⭐ The service desk, trained on the specific tickets this change creates.
3. What is wrong with "any questions?" as a check?
   → ⭐ Silence gets measured as understanding; the person who most needs help asks least.
4. Describe the planted-event technique and what it proves.
   → ⭐ Create an audit event beforehand; ask them to find it. They cannot pass by nodding.
5. Why train in the customer's tenant?
   → ⭐ A demo tenant teaches the product; theirs teaches their system.
6. Why two people per task?
   → ⭐ The single trained person will be on leave during the first incident.
7. Which competency row is most often skipped, and why does that matter?
   → ⭐ Break-glass rehearsal — it requires breaking a seal, and untested recovery is not recovery.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | ⭐ the completed competency matrix with names, dates and observer |
| `operations` | the handed-over health-check script and one run by the customer |
| `customer-use-cases` | the service desk's top-5 ticket guide |
| `break-fix` | ⭐ the break-glass rehearsal record, including the reseal |
| `architecture-decisions` | the training plan, and any design simplified because it was untrainable |

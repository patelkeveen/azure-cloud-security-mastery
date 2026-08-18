# Cutover Playbooks

> Written to [`../../CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> ⚠ **Boundary:** this is the **artifact and the command structure** — who decides, who speaks, how
> it is recorded. The **mechanism** of a mail cutover is
> [`../../45-m365-migration-engineering/cutover-and-rollback/`](../../45-m365-migration-engineering/cutover-and-rollback/).
> ⭐ **That topic tells you what to do; this one tells you how twelve people do it together at 02:00.**

---

## 1. What it is

The single document that runs a cutover night: the timed step list, the named owners, the
verification per step, the go/no-go gates, the communications, and the decision log. It is written
to be executed by people who are tired, in parallel, some of whom do not work for you.

⭐ **A playbook is not a longer runbook. It is a command structure with a timetable attached.**

---

## 2. Why it exists

⭐ **The technical steps are the easy part.** What fails on the night is coordination:

| Failure | What it looks like at 02:40 |
|---|---|
| ⭐ **No single decision-maker** | four people discussing whether to roll back |
| Unclear ownership | ⭐ two people change DNS simultaneously |
| ⭐ **Verification by opinion** | *"looks fine to me"* — from someone testing the wrong thing |
| No decision log | ⭐ nobody can reconstruct why the window ran over |
| Comms improvised | users find out from the helpdesk queue |
| ⭐ **Rollback debated live** | ⭐ the window closes while the argument continues |

⭐ **The playbook exists to move every judgement out of the night and into the daylight** — the
criteria, the owners, the abort conditions, all decided when people were rested and unpressured.

---

## 3. How it works underneath — roles, and why they must be separate

```
⭐ CUTOVER LEAD        the ONLY person who says go, no-go, or roll back
                       ⭐ does NOT execute steps - if they are typing,
                          they are not watching
      │
      ├─ EXECUTOR(s)   perform steps; report "step 5 complete, verified"
      │
      ├─ ⭐ VERIFIER    ⭐ INDEPENDENT of the executor. Tests as a USER,
      │                 not as an admin
      │
      ├─ COMMS         sends the pre-written messages; ⭐ owns the clock
      │
      └─ ⭐ SCRIBE      ⭐ timestamps every step and every decision
                        - this is the artifact that survives the night
```

⭐ **Executor and verifier must be different people.** The person who made the change cannot
objectively test it; they will test the path they just built and see it work. ⭐ **This is the same
principle as separation of duties in access control**, applied to an evening.

⭐ **The lead not executing is counter-intuitive and non-negotiable.** A lead with a terminal open
loses situational awareness exactly when it is needed. ⭐ **On a small engagement you may hold two
roles — but never lead *and* executor.**

---

## 4. Worked example — the playbook page as it is actually used

⭐ **One row per step. If a row has no verification or no owner, it is not ready.**

```
PLAYBOOK  Contoso M365 cutover      Window 2026-09-12 22:00 - 03:00 IST
Lead K. Patel   Exec D. Mwangi   Verify L. Petrov   Comms S. Roy   Scribe A. Bose
War room: Teams "Cutover-Bridge" ⭐ OPEN FROM 21:45, nobody leaves until stood down

 #  Time   Step                        Owner  ⭐ Verification            Rollback   Done
────────────────────────────────────────────────────────────────────────────────────────
 1  21:45  Bridge open, roll call      Lead   all 5 present              -          ____
 2  22:00  ⭐ GO/NO-GO #1               Lead   ⭐ batches Synced,          ⭐ ABORT    ____
                                              ⭐ FailedCount = 0          free
 3  22:15  Comms: "starting"           Comms  send log                   -          ____
 4  22:20  Complete migration batch    Exec   Status = Completed         ⭐ NONE     ____
 5  22:50  Change MX                   Exec   dig MX = *.protection…     revert 5m  ____
 6  22:55  Change autodiscover CNAME   Exec   nslookup = outlook.com     revert 5m  ____
 7  23:10  ⭐ EXTERNAL mail test        ⭐Verify ⭐ personal address →      revert 5,6 ____
                                              lands < 5 min
 8  23:20  Internal → external test    Verify received, headers = EXO    revert 5,6 ____
 9  23:30  Client test 3 users         Verify ⭐ Outlook reconnects       see §7     ____
                                              ⭐ WITHOUT new profile
10  23:45  ⭐ GO/NO-GO #2               Lead   steps 7-9 all pass         ⭐ LAST     ____
                                                                         clean point
11  00:00  Comms: "complete"           Comms  send log                   -          ____
12  00:00  ⭐ HYPERCARE begins           Lead   ⭐ rota published           -          ____

⭐ ABORT CRITERIA - decided 2026-09-05, not tonight
   ▸ Step 7 fails twice          → roll back
   ▸ ⭐ Any step overruns by 45 min → Lead calls it, no discussion
   ▸ ⭐ Lead unreachable 10 min    → D. Mwangi assumes Lead role
```

⭐ **The abort criteria block, with its authoring date, is the most important eight lines on the
page.** *"Any step overruns by 45 minutes → the Lead calls it, no discussion"* is a decision made a
week earlier by people who were not tired. ⭐ **At 02:40, sunk cost is overwhelming and every
instinct says "we're nearly there" — a pre-written criterion is the only thing that reliably
overrides it.**

⭐ **The succession line matters too.** *"Lead unreachable for 10 minutes → named deputy assumes the
role"* prevents the worst outcome of the night: twelve people waiting for one person's phone to
connect.

**The decision log the scribe keeps — this is the deliverable:**

```
22:52  Step 5 executed. MX confirmed at 3 external resolvers.        [Exec]
23:14  ⭐ Step 7 FAILED first attempt - test mail not received in 5m.  [Verify]
23:16  ⭐ DECISION (Lead): retry once before invoking abort criteria.  [Lead]
23:19  Step 7 PASSED on retry. Root cause: sender-side greylisting.  [Verify]
23:47  GO/NO-GO #2: PASS. Proceeding.                                [Lead]
```

⭐ **That log answers every question asked in the following week**, including the ones asked by
people who want to know why it took an extra twenty minutes. Without it, you are reconstructing the
night from memory and Teams scrollback.

---

## 5. Commands — the verifier's kit, prepared in advance

⭐ **Every command the verifier will need is pasted into the playbook *before* the night**, tested
in advance. Nobody composes a filter at 23:10.

```powershell
# Step 2 gate - the only number that matters
Get-MigrationBatch | Select-Object Identity, Status, FailedCount
```

```
Identity         Status     FailedCount
Wave-Final       Synced               0
```

```powershell
# Step 7 - evidence, not opinion
Get-MessageTrace -StartDate (Get-Date).AddMinutes(-15) -EndDate (Get-Date) |
  Select-Object Received, SenderAddress, RecipientAddress, Status
```

```
Received             SenderAddress     RecipientAddress      Status
12/09/2026 23:19:04  test@gmail.com    j.smith@contoso.com   Delivered
```

⭐ **`Status: Delivered` with a timestamp is a verification. "I got the email" is a claim.** The
difference is what the scribe can paste into the log.

⭐ **Hypercare is a playbook step, not an afterthought.** Step 12 publishes a rota: who is reachable,
for how long, and how the customer contacts them. ⭐ **The 48 hours after a cutover generate more
tickets than the cutover itself**, and an unstaffed morning after undoes a flawless night.

---

## 6. When and where

| Change | Artifact |
|---|---|
| ⭐ Multi-party, irreversible, timeboxed | ⭐ **full playbook** |
| Single-admin config change | ⭐ a checklist — [`../configuration-checklists/`](../configuration-checklists/) |
| Recurring operational task | an SOP — [`../sop-and-runbooks/`](../sop-and-runbooks/) |
| Incident response | ⭐ related but different: [`../../70-operations-and-reliability/incident-command/`](../../70-operations-and-reliability/incident-command/) |

⭐ **Rehearse the playbook in a test tenant, or at minimum read it aloud on the bridge 48 hours
before.** ⭐ **Reading it aloud finds the missing owner, the step with no verification, and the
person who did not know they were on the call** — for the cost of twenty minutes.

---

## 7. What breaks

| Symptom | Root cause | Fix |
|---|---|---|
| Rollback debated live | criteria not pre-written | ⭐ §4 abort block, dated |
| Two people changed the same thing | one row, two owners | ⭐ exactly one owner per row |
| "It works" then users disagree | ⭐ executor verified own work | ⭐ independent verifier, testing as a user |
| Window overruns silently | no time-based abort | ⭐ the 45-minute rule |
| Nobody can explain the night | no scribe | ⭐ appoint one; it is a real role |
| ⭐ Morning after is chaos | ⭐ no hypercare rota | step 12 |
| Lead unreachable, all stop | no succession | named deputy in the header |

⭐ **"The executor verified their own work" is the most common and most expensive failure**, because
it produces a *confident* wrong answer. The verifier must test the way a user experiences the
service — from an external address, on a client, without admin rights.

---

## 8. Customer discovery questions

1. ⭐ **"Who has authority to call a rollback, and will they be on the bridge?"**
2. "Which of your people must be present, and are they available at that hour?"
3. ⭐ **"What is the latest we can still roll back and finish before business hours?"**
4. "Who tells users, through which channel, and who approves that text?"
5. "Do any third parties need to act during the window, and what is their response time?"
6. ⭐ **"Who is staffing the morning after?"**
7. "Where should the decision log be stored afterwards?"

---

## 9. Remember it

**Hook — `L E V C S`: Lead, Executor, Verifier, Comms, Scribe.** Five roles; ⭐ **Lead never types,
Verifier is never the Executor.**

**Analogy — a theatre production, not a solo performance.** ⭐ **The director does not act; the stage
manager calls the cues from the book; someone else watches from the auditorium to see what the
audience sees.** The analogy is load-bearing: it predicts why the lead must not execute (⭐ a
director acting cannot see the stage), why the verifier tests as a user (⭐ the view from the
auditorium is the only one that counts), why the prompt book exists (⭐ the scribe's log), and why
you rehearse.

**The one line:** ⭐ **Move every judgement into daylight — owners, verifications and abort criteria
written and dated before the night.**

---

## 10. Self-test

1. Why must the cutover lead not execute steps?
   → ⭐ Typing costs situational awareness exactly when it is needed.
2. Why must the verifier differ from the executor?
   → ⭐ The builder tests the path they built and sees it work.
3. What makes an abort criterion effective?
   → ⭐ It is written and dated in advance, so sunk cost cannot override it.
4. What does the scribe produce, and who uses it?
   → ⭐ A timestamped decision log — the artifact that answers the following week's questions.
5. Verification: "I got the test email" — sufficient?
   → ⭐ No. `Get-MessageTrace` with `Delivered` and a timestamp is evidence.
6. What happens if the lead is unreachable for ten minutes?
   → ⭐ A named deputy assumes the role — written in the header.
7. Cheapest way to find defects in a playbook?
   → ⭐ Read it aloud on the bridge 48 hours before.

---

## 11. Evidence this topic needs

| Facet | Artifact |
|---|---|
| `lab` | a completed playbook with real timestamps and initials |
| `operations` | ⭐ the scribe's decision log from one real cutover |
| `break-fix` | one step that failed, and the decision recorded at the time |
| `customer-use-cases` | the comms pack and the hypercare rota |
| `architecture-decisions` | ⭐ the abort criteria, dated before the window |

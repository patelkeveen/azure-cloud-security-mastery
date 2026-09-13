# SC-300 — the final four days

**Monday 14 September 2026 → exam Friday 18 September 2026, 07:30 IST, online proctored (Pearson VUE OnVUE).**
Written 2026-09-14. Blueprint, logistics and proctoring rules verified live the same day.

> **This file supersedes [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md) and §5 of
> [`EXAM-DAY.md`](EXAM-DAY.md).** Both were written for a sitting on 31 August and then
> re-dated; both assume a live E5 tenant. **SC-200 has been postponed to October**, so SC-300 is
> now the only exam in the window and gets all four days.

---

## 1. What changed, and what it means

**The E5 trial has ended. The Azure credits are exhausted. There is no tenant and no budget.**

Every lab-driven instruction in this sprint — `DAY-1.md` through `DAY-7.md`, the `Day0`/`Day1`
PowerShell, the audit-log fix in `EXAM-COUNTDOWN.md` §2 — is now moot. Do not open them.

**This is less of a loss than it feels like**, and it is worth being precise about why. With four
days left, the binding constraint was never exposure — it was **recall and discrimination**. Your own
`EXAM-COUNTDOWN.md` said it in August: *"Recall is what is short now, not exposure."* A lab teaches
you that a blade exists. The exam asks you to choose between two blades that both look right. Those
are trained differently, and the second one needs no tenant at all.

**The good news, verified today:** the blueprint has not moved under you. SC-300's skills are
*measured as of 27 April 2026*, and the April revision changed no domain names, added no groups,
removed none, and altered no weights — only five "Minor" skill-group edits. Your D1 20–25% /
D2 25–30% / D3 20–25% / D4 20–25% material is current. **SC-200 was the exam restructured in July,
not this one.**

**The bad news, also verified today:** three entire live skill groups have **zero** coverage in the
`EXPLAIN/` files you revise from. They are in [`BLIND-SPOTS.md`](BLIND-SPOTS.md) and they are the
first thing you should read.

---

## 2. The one decision to make before you start

**Do you spend Monday morning trying to get a tenant back?**

The research found a real path: your `KWin.onmicrosoft.com` tenant and everything in it — CA
policies, app registrations, catalogs, access packages — **still exists**. The E5 subscription
expired but the directory objects were frozen, not deleted. A standalone **Entra ID P2 30-day
trial** activated on that tenant would unfreeze P2 features in 15–30 minutes.

**The honest cost-benefit:**

| For | Against |
|---|---|
| P2 features become clickable again — CA, PIM, ID Protection, access reviews | **A payment method is required on the billing profile even at ₹0** — verified; there is no card-free path |
| Everything you built in August is still there | **Auto-converts to paid at ~$10/user/month** if recurring billing is not switched off |
| Restores roughly half the blueprint as live labs | The trial button being offered to *your specific tenant* is **unverified** — medium confidence |
| | You have four days. Marginal value of clicking over reciting is **low** this late |

**My recommendation: skip it, or timebox it to 30 minutes on Monday and abandon it if it resists.**
The four days below are built to work with no tenant at all. If you do activate it, set **two phone
alarms for 10 October** and turn off recurring billing the moment the order completes.

**What is genuinely free and worth the time instead:**

| Asset | Cost | Use it |
|---|---|---|
| [SC-300 practice assessment](https://learn.microsoft.com/en-us/credentials/certifications/identity-and-access-administrator/practice/assessment?assessment-type=practice&assessmentId=60&practice-assessment-type=certification) | Free, unlimited | **Monday cold**, then Wednesday, then Thursday |
| [Exam sandbox — `aka.ms/examdemo`](https://aka.ms/examdemo) | Free, no sign-in | **Thursday, 20 min.** Every question type in the real UI |
| [Applied Skills: identities and access](https://learn.microsoft.com/en-us/credentials/applied-skills/get-started-with-identities-and-access-using-microsoft-entra/) | Free | A **real Microsoft-provisioned tenant**, 30 min, graded. 72-hour cooldown, so at most two runs before Friday |
| [OnVUE system test](https://system-test.onvue.com/system_test?customer=pearson_vue&clientcode=MICROSOFT&locale=en_US) | Free | **Today, Wednesday, and Friday morning** — on the exam machine, in the exam room |

That Applied Skills lab is the closest thing to a free tenant you have, and it covers users, groups,
SSPR, MFA and Conditional Access tasks. **Run it Monday evening.**

---

## 3. The four days

Ordered by **weight × unfamiliarity** — the biggest domain you know least well goes first.

### Monday 14 — the holes

```
Morning    Practice assessment COLD, before any revision.            60 min
           Score by domain. That score is the plan, not this file.
           (Optional, timeboxed) P2 trial attempt.                   30 min
Afternoon  BLIND-SPOTS.md §1 Global Secure Access                    60 min
           BLIND-SPOTS.md §3 Monitor identity activity               60 min
           Both OUT LOUD. These are D2 and D4 material you have zero notes on.
Evening    EXPLAIN/D2-AUTH-AND-ACCESS.md, all 13 concepts, out loud  90 min
           Applied Skills lab (free real tenant)                     30 min
```

**Why the cold assessment first:** a baseline taken *before* revision tells you which domain is
actually weak. Taken after, it tells you nothing except that you just read the material. This is the
same rule as the SC-200 pack and it is the single most commonly skipped step.

### Tuesday 15 — the biggest domain

```
Morning    BLIND-SPOTS.md §2 Defender for Cloud Apps, in full        75 min
           Access policy vs session policy until it is automatic.
           DISCRIMINATORS.md D2, cover-the-answer                    60 min
Afternoon  BLIND-SPOTS.md §4 rapid-fire, D2 half                     45 min
           Security defaults · protected actions · auth context ·
           CA templates · registration campaigns · CBA · Entra Kerberos
           EXPLAIN/D3-WORKLOAD-IDENTITIES.md out loud                60 min
Evening    DISCRIMINATORS.md D3 + GAP-DRILL.md §6 consent            60 min
```

### Wednesday 16 — governance and the tail

```
Morning    EXPLAIN/D4-GOVERNANCE.md out loud                         60 min
           DISCRIMINATORS.md D4                                      45 min
Afternoon  EXPLAIN/D1-USER-IDENTITIES.md out loud                    60 min
           GAP-DRILL.md §1 admin units · §3 hybrid · §7 external     60 min
           BLIND-SPOTS.md §4 rapid-fire, D1 + D3 half                45 min
Evening    Practice assessment, SECOND pass, timed                   60 min
           Score it. Write down WHY each miss was wrong.             45 min
           OnVUE system test on the exam machine.                    15 min
```

**The "why" is the whole exercise.** Sort every miss into three buckets:
*didn't know it* → go read · *knew it, misread the stem* → a technique problem, see §5 ·
*knew it, talked myself out of it* → stop doing that.

### Thursday 17 — recall only, and stop early

```
Morning    DISCRIMINATORS.md, all four domains, tells only           90 min
           Cover the left column. Say the tell.
           GAP-DRILL.md §8 — the ten one-liners                      20 min
Afternoon  Practice assessment THIRD pass                            60 min
           Only the topics you missed twice                          60 min
           aka.ms/examdemo — every question type                     20 min
           Applied Skills lab, second run (if 72 h has elapsed)      30 min
Evening    LOGISTICS BLOCK — §4 below. Do all of it.                 45 min
17:00      STOP. No new material. Nothing.
```

**Stopping Thursday evening is a technique, not a reward.** You are sitting at 07:30; you need to be
asleep by 22:30 at the latest. Cramming the night before a 07:30 exam costs more in fatigue than it
adds in recall, and the last thing you read tends to crowd out something you already knew.

---

## 4. The logistics block — Thursday evening, all of it

**Everything here is verified against Microsoft and Pearson VUE pages as of 2026-09-14.** Any one of
these can end the sitting before a single question is asked, and **the ID one cannot be fixed on
Friday.**

### 4.1 The name check — do this now, not Thursday

> **The first and last name on your physical ID must EXACTLY match your Microsoft Certification
> profile.** Renewal paperwork and name-change documents are **not accepted** for online exams, and
> any ID exception needs Microsoft pre-approval **at least five business days ahead** — which is
> already too late for Friday.

Check it here: <https://learn.microsoft.com/en-us/credentials/certifications/manage-certification-profile>

### 4.2 Which ID to use — India specifics

| | |
|---|---|
| **Safest** | **Indian passport** — photo page, all four corners in frame |
| Acceptable | **UIDAI-issued PVC (plastic) Aadhaar card** only — with ghost image and guilloche pattern |
| Acceptable | State RTO **driving licence card** — capture front and back |
| **Rejected** | e-Aadhaar printout · laminated paper Aadhaar · **privately printed PVC Aadhaar** · photocopies · digital/phone-app IDs · expired or damaged IDs |
| **Not on the accepted list** | PAN card, Voter ID — do not rely on them |

*(Per Pearson's Aadhaar ID Policy v1.2, May 2026. The PAN/Voter exclusion is inferred from the
accepted-ID list rather than stated explicitly — so use the passport and remove the question.)*

### 4.3 The room, Friday 07:00

- **Enclosed room, door closed.** Nobody may enter or pass through. Tell the household the night
  before — a family member walking in is an immediate revocation risk.
- **Desk completely clear.** No paper, no pens, no notes, no Post-its, no tissue box, no food. A
  drink is allowed only in a **transparent, unlabelled** container.
- **One display.** Unplug and turn away any second monitor; switch off other computers in the room.
- **No headphones or earbuds** — speakers and mic must work. No watch, no smartwatch, no hat or
  hood, no jacket.
- **Phone stays in the room**, out of arm's reach, ringer on, with **+91 on your Learn profile**.
  Do not touch it, including during a break.
- You will take **four room photos, a headshot and ID photos** at check-in, and may be asked for a
  **360° room scan** at check-in or mid-exam.

### 4.4 The machine

- **Personal, not employer-managed**, Windows 10+ with local admin. Your own laptop.
- **Disconnect every VPN.** Close every application — OnVUE force-closes them and that can crash
  the launch and forfeit the fee.
- **Wired Ethernet if possible**; at least 6 Mbps down / 2 Mbps up. Ask the household not to stream.
- **Plug in the power cord.** Pause antivirus real-time scanning.
- **Run the system test Thursday and again Friday morning**, on the same machine, network and room.

### 4.5 Friday morning — the timeline

```
06:30  Up. Eat something. A 100-minute exam on an empty stomach is a self-inflicted handicap.
06:45  Room staged. Desk clear. Second monitor unplugged. VPN off. Phone across the room.
06:50  System test, final run.
06:55  Seated.
07:00  START CHECK-IN.   <- the window is 30 min before to 15 min after. Check-in itself takes ~15 min.
07:30  Exam.
```

**Missing the check-in window is a no-show with no refund.** Starting at 07:00 gives you thirty
minutes of margin on a process that routinely takes fifteen.

**Read nothing new on Friday.** `GAP-DRILL.md` §8 — the ten one-liners — and the DISCRIMINATORS
tells. That is all.

---

## 5. Exam technique — the rules that are specific to this paper

**Format, verified:** 100 minutes of exam time, 120 minutes of seat time, typically **40–60
questions**, **700 of 1000 scaled** to pass, **no penalty for guessing**. Answer everything.

### 5.1 The three places you cannot go back — this is the big one

| | |
|---|---|
| **Problem-solution "Yes/No" sets** | *"Does this solution meet the goal?"* — once answered you **cannot return**, and they never appear on the review screen. **The solutions are independent: two can both be Yes.** |
| **Case studies** | Reviewable within the case, but **once you leave a case study you cannot return to it** |
| **After a break** | You **cannot return to any question seen before the break**, even unanswered or flagged ones |

**Consequence:** before you click past a section boundary or start a break, clear the review screen.
Never leave a seen question blank.

### 5.2 The break

Unscheduled breaks **are** allowed on SC-300 — five minutes are built into the time — but **the clock
keeps running** and you lose access to everything you have already seen. You must start it via the
**"Take a break"** icon; leaving the webcam view without it gets the exam revoked.

**Recommendation for 100 minutes: plan for no break.**

### 5.3 In-exam Microsoft Learn access — use it, sparingly

Associate-level exams provide a **split-screen browser limited to `learn.microsoft.com`** (no Q&A, no
practice assessments, no profile). **The timer keeps running.**

> **Use it for one to three lookups on questions you have flagged, at the end — never as a crutch
> mid-paper.** Most candidates either forget it exists or burn twenty minutes in it. Decide now which
> you will be: two lookups, maximum, in the last ten minutes.

### 5.4 Pacing

```
~1.5 min per standard question
Case study: read the REQUIREMENTS tab first, then the questions, then the rest only if needed
Reserve the last 10 minutes for flagged questions and your Learn lookups
```

**If a question will take four minutes, flag it and move.** Running out of time is a far more common
failure than getting hard questions wrong.

### 5.5 The constraint words that decide the answer

```
"least privilege"               -> Global Administrator is wrong. Always.
"minimum administrative effort" -> the built-in feature beats the custom one
"fewest changes"                -> do not rebuild what already exists
"must not appear in the directory" -> B2B direct connect, not collaboration
"if the on-prem site is down"   -> PHS
"including administrators"      -> the Privileged variant of the role
"without storing passwords"     -> PTA or federation
"without relying on IP addresses" -> compliant network check (Global Secure Access)
"allow access but block download" -> CA App Control, session policy
"no premium licences"           -> security defaults
```

### 5.6 Reason from the mechanism when you blank

```
Who is present?        user present -> delegated (scp)   |  no user -> application (roles)
What is constrained?   verbs -> custom role              |  nouns -> administrative unit
When is it evaluated?  at sign-in -> CA                  |  continuously -> CAE
How long is it held?   can activate -> eligible          |  holds it now -> active
Where is the password checked?  in Entra -> PHS          |  on-prem -> PTA / federation
Grant or govern?       decides a sign-in -> CA           |  decides who may request -> entitlement mgmt
```

**Trust your first instinct on recall questions.** Change an answer only when you can name the
specific fact that makes the new one right. *"It feels wrong now"* is fatigue, not insight.

---

## 6. Afterwards

You get a **provisional result on screen within minutes**. Whatever it says, **write down the
weakest domain from the score report before you close it** — it is the honest input to the SC-200
plan in October, and it is exactly what an interviewer will probe.

**Retake policy, verified:** fail once → 24-hour wait. Every attempt after that → **14 days**.
Maximum five attempts in the 12 months from your first. Each retake is paid.

---

## 7. What this plan does not pretend

**It does not make you good at hybrid identity.** No domain controller, so PHS, PTA, federation,
Connect and password writeback are theory. [`GAP-DRILL.md`](GAP-DRILL.md) §3 gets you to
exam-answerable, not to competent. Say that plainly in an interview and it reads as judgement;
imply otherwise and it collapses on the first follow-up.

**It does not lab Global Secure Access, Defender for Cloud Apps or Log Analytics.** All three need
licences you no longer hold. They are examinable as decision models, and
[`BLIND-SPOTS.md`](BLIND-SPOTS.md) is those decision models.

**It was not fully adversarially verified.** The skeptic pass that normally refutes every
time-sensitive claim in a pack like this was killed partway by a monthly spend limit. The blueprint,
logistics and proctoring facts came back verified with URLs; **the P2-trial availability and the D4
discriminators did not get a second opinion.** Treat specific numbers as checkable, the reasoning as
sound.

> **Related:** [`BLIND-SPOTS.md`](BLIND-SPOTS.md) — three uncovered skill groups ·
> [`DISCRIMINATORS.md`](DISCRIMINATORS.md) — 83 pairs with exam tells ·
> [`GAP-DRILL.md`](GAP-DRILL.md) · [`EXPLAIN/`](EXPLAIN/) ·
> [`sc-300-lexicon.html`](sc-300-lexicon.html) — 274 terms, 83 traps flagged

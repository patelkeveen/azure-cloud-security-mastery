# Exam day — technique, and the morning of

> ⭐ **Read this once on Thursday 27 August and once on the morning.** Not more.
> **Exam: SC-300, Friday 28 August 2026.**

---

## 1. What is actually being scored

> ⭐ **Baseline, dated so it can go stale visibly:** Microsoft Learn lists SC-300 **skills
> measured as of 2026-04-27**, study-guide page **last updated 2026-03-27**. ⭐ **Re-check before
> you sit it** — [official study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-300).

⭐ **Pass mark is 700 out of 1000, and it is scaled — not "70% of questions".** Questions carry
different weights and there is no published mapping, so ⭐ **there is no such thing as a question
you can safely write off.**

Domain weightings, and therefore where to spend a tiebreak minute:

| Domain | Weight | Your sprint days |
|---|---|---|
| Implement and manage user identities | 20–25% | 1, 7 |
| ⭐ **Authentication and access management** | ⚠ **25–30%** | ⭐ **2, 3** |
| Plan and implement workload identities | 20–25% | 6 |
| Plan and automate identity governance | 20–25% | 4, 5 |

⚠ **Microsoft's own page contradicts itself on the second row** — "Skills at a glance" says
25–30%, the detail section says 20–25%. ⭐ **Either way Conditional Access and authentication are
the largest block. If you are short on time on Wednesday, revise Day 3 again.**

---

## 2. Question formats, and the one that catches people

- **Single answer** and **multi-select** ("choose two" — ⭐ *choosing three scores zero, not
  partial*).
- **Drag and drop / build list** — ordering steps, matching a control to a requirement.
- **Hot area** — pick values from dropdowns inside a config screenshot.
- **Case study** — a scenario with tabs (overview, existing environment, requirements) and several
  questions against it. ⭐ **Read the *requirements* tab first, then the questions, then the rest
  only if you still need it.**
- ⭐ **The repeated-scenario set.** Several questions share one scenario; each proposes a different
  solution and asks *"Does this meet the goal?" — Yes / No.* ⭐ **The solutions are independent.
  Two of them can both be correct.** Judge each on its own; do not assume only one "Yes".

### ⚠ The warning you must not skim

> *"You cannot return to this question."*

⭐ **Some sections lock behind you.** When you see that banner, stop and finish the question
properly — flagging it for review does nothing. ⭐ **Everything else: use the review flag freely
and come back.**

---

## 3. Time budget

Seat time is around **100 minutes** for the questions (the appointment is longer — agreements,
system check, survey). ⭐ **Check the on-screen timer at the start; it is authoritative, this file
is not.**

```
Rough pacing:  ~1.5 min per standard question
Case study:    read once properly, then ~2 min per question against it
⭐ Reserve the last 10 minutes for flagged questions
```

⭐ **If a question is going to take four minutes, flag it and move.** Two easy questions later in
the paper are worth more than one hard one now, and ⚠ **running out of time is a far more common
failure than getting hard questions wrong.**

---

## 4. ⭐ The five reading habits that convert knowledge into marks

**1. ⭐ Read the last sentence first.** The scenario is context; the final line is the question.
Half of all misreads are answering a question the paper did not ask.

**2. ⭐ Hunt the constraint words.** They are the whole answer:

```
"least privilege"              -> ⭐ Global Administrator is wrong. Always.
"minimum administrative effort"-> the built-in feature beats the custom one
"fewest changes"               -> do not rebuild what already exists
"must not appear in directory" -> B2B direct connect, not collaboration
"if the on-prem site is down"  -> PHS
"including administrators"     -> the Privileged variant of the role
"without storing passwords"    -> PTA or federation
```

**3. ⭐ Eliminate first.** Two of four options are usually disqualified by a single constraint.
Killing those is faster and more reliable than arguing yourself into the right one.

**4. ⭐ Watch for the plausible-but-superseded answer.** Legacy MFA / SSPR per-user settings, the
old baseline policies, per-user MFA enforcement — ⭐ **all still recognisable, all the wrong answer
now.** The converged **authentication methods policy** and **Conditional Access** are the modern
answers.

**5. ⭐ Trust your first instinct on recall questions.** Change an answer only when you can name
the specific fact that makes the new one right. ⚠ **"It feels wrong now" is fatigue, not insight.**

---

## 5. The morning of

```
[] Eat. A three-hour appointment on an empty stomach is a self-inflicted handicap.
[] ⭐ Read RETENTION.md sec.9 (90-second refresher) and GAP-DRILL.md sec.8 (ten one-liners).
[] ⭐ Nothing else. No new material. No practice test.
[] ID that matches the booking name EXACTLY.
[] Online proctored: clear desk, run the system check EARLY, close everything.
[] Arrive / log in 20-30 minutes early.
```

⚠ **The system check is the single most common avoidable failure.** Run it the night before *and*
on the morning.

---

## 6. ⭐ If you blank

⭐ **Flag it and move on. That is the correct answer to blanking.** Recall returns when the
pressure moves elsewhere, and a later question often contains the term you were reaching for.

⭐ **When you genuinely do not know, reason from the mechanism rather than guessing:**

```
Who is present?         user present -> delegated (scp)   |  no user -> application (roles)
What is constrained?    verbs -> custom role              |  nouns -> administrative unit
When is it evaluated?   sign-in -> CA                     |  continuously -> CAE
How long is it held?    can activate -> eligible          |  holds it now -> active
Where is the password checked?   in Entra -> PHS          |  on-prem -> PTA / federation
```

⭐ **Those five questions resolve a surprising share of the paper**, because SC-300 is mostly one
idea asked repeatedly: **who is asking, for what, under which condition, for how long.**

---

## 7. Afterwards

⭐ **You get a provisional result on screen immediately.** Whatever it says:

- **Pass** → the score report names your weakest domain. ⭐ **Write it down before you close it** —
  it is the honest input to SC-200 planning, and it will be the thing an interviewer probes.
- **Not this time** → ⚠ **there is a mandatory wait before a retake (24 hours for the first, longer
  after that).** The score report is a free, precise gap analysis. ⭐ **Book the retake the same
  week — the material decays fast and you will never be closer to it than you are that day.**

⭐ **Either way, 29 August is the evidence sweep** — [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md) §3
deferred it, the E5 trial runs to **2026-09-10**, and the repo is still **WRITTEN 0/144**.

⚠ **And cancel or diarise the trial by 2026-09-05** or it converts to paid at E5 rates.

> **Related:** [`EXAM-COUNTDOWN.md`](EXAM-COUNTDOWN.md) · [`GAP-DRILL.md`](GAP-DRILL.md) ·
> [`../RETENTION.md`](../RETENTION.md) §9 · [`../SC-300-MASTERY-SYLLABUS.md`](../SC-300-MASTERY-SYLLABUS.md)

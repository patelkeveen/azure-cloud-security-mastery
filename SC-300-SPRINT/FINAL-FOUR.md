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

**The bad news, also verified today:** three entire live skill groups — Global Secure Access,
Defender for Cloud Apps, and monitoring/logs/workbooks — have **zero** coverage in the four
`EXPLAIN/` four-level explainer files.

**Measured correction:** your *question bank* does cover them — 6, 10 and 12 questions respectively,
28 of 180, plus 16 flashcards. So this is not unseen material. It is **28 questions you have no
explainer behind**, which is why a miss there never converts into a fix.
[`BLIND-SPOTS.md`](BLIND-SPOTS.md) is the missing explainer layer, and it is the first thing to read.

---

## 2. The tenant question — answered, and the answer is no

> ### ⚠ Correction — verified 2026-09-14, refuted 3 skeptics to 0
>
> An earlier version of this file called a P2 trial on your old tenant *"a real path"* and told you
> to timebox it to 30 minutes. **Three independent checks refuted it. Do not attempt it.**

**Four reasons, each sufficient on its own:**

1. **You are probably not eligible.** Trials are one per tenant per product, and
   `KWin.onmicrosoft.com` already ran Microsoft 365 E5 — which provisioned `AAD_PREMIUM_P2`.
   Microsoft's documented gate for the sibling Governance trial is that the tenant *"isn't already
   using or has previously trialed"* the product. The button may simply not appear.
2. **There is no billing profile to reuse.** Microsoft has not stored card details for India since
   **30 September 2022** under the RBI directive. You would be entering a **live card**, not
   re-using one.
3. **It auto-converts to a paid ANNUAL subscription** at whatever licence count the order page
   defaults to. On a furloughed budget that is a real, recurring liability for a lab you need for
   three days.
4. **The restoration promise was false for the part you cared about.** When the P2 licence lapsed,
   **PIM eligible assignments were removed** and time-bound active ones became permanent. Your CA
   policies and app registrations survive; your PIM configuration did not.

**So: no tenant. The four days below are built for that, and it costs you less than it feels like.**
With three and a half days left the binding constraint is recall and discrimination, not exposure —
your own August pack said exactly that.

**What is genuinely free and worth the time instead:**

| Asset | Cost | Use it |
|---|---|---|
| [SC-300 practice assessment](https://learn.microsoft.com/en-us/credentials/certifications/identity-and-access-administrator/practice/assessment?assessment-type=practice&assessmentId=60&practice-assessment-type=certification) | Free, unlimited | **Today, cold**, then Wednesday, then Thursday |
| [Exam sandbox — `aka.ms/examdemo`](https://aka.ms/examdemo) | Free, no sign-in | **Thursday, 20 min.** Every question type in the real UI |
| [Applied Skills: identities and access](https://learn.microsoft.com/en-us/credentials/applied-skills/get-started-with-identities-and-access-using-microsoft-entra/) | Free | A **real Microsoft-provisioned tenant**, 30 min, graded. 72-hour cooldown, so at most two runs before Friday |
| [OnVUE system test](https://system-test.onvue.com/system_test?customer=pearson_vue&clientcode=MICROSOFT&locale=en_US) | Free | **Today, Wednesday, Friday morning** — same machine, same network, same room |

That Applied Skills lab is the closest thing to a free tenant you have — users, groups, SSPR, MFA
and Conditional Access tasks in a real directory. **Run it tonight.**

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
           Both OUT LOUD. 18 bank questions test these and you have no explainer.
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
           PRACTITIONER-TRAPS.md — all 22, out loud                  45 min
           The highest-value file in the pack. Where your own
           experience makes you pick the wrong answer.
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
> profile.** Renewal paperwork and name-change documents are **not accepted** for online proctored
> exams (test centres do accept them — online does not).
>
> ### ⚠ Corrected 2026-09-14 — refuted 3/3, and this one is actionable
>
> An earlier version said an ID exception needs **Microsoft** approval **five business days** ahead
> and was therefore already too late. **Both parts were wrong.** An exception is pre-approved by
> **Pearson VUE customer service**, at least **three business days** before the appointment. For an
> 18 September sitting that deadline is around **Tuesday 15 September — tomorrow.**
>
> **So if you have an ID problem, it is still fixable. Call Pearson VUE today.**

Check it here: <https://learn.microsoft.com/en-us/credentials/certifications/manage-certification-profile>

### 4.2 Which ID to use — India specifics

| | |
|---|---|
| **Safest** | **Indian passport** — photo page, all four corners in frame |
| Acceptable | **UIDAI-issued PVC (plastic) Aadhaar card** only — with ghost image and guilloche pattern |
| Acceptable | State RTO **driving licence card** — capture front and back |
| **Rejected** | e-Aadhaar printout · laminated paper Aadhaar · **privately printed PVC Aadhaar** · photocopies · digital/phone-app IDs · expired or damaged IDs |
| **Not on the accepted list** | PAN card, Voter ID — do not rely on them |

*(Per Pearson's Aadhaar ID Policy v1.2, May 2026.)*

**Two additions from the verification pass:** Microsoft's ID wording requires **name, photo AND
signature** — the passport carries all three, the PVC Aadhaar does not list a signature. And
**paper IDs are accepted in only four countries** (Algeria, Brazil, Cameroon, Dominican Republic),
so any paper Aadhaar is out regardless of condition.

**PAN and Voter ID are "not enumerated" rather than "published as rejected"** — an unsourced
negative, not a confirmed exclusion. Use the passport and the question disappears.

### 4.3 The room, Friday 07:00

- **Enclosed room, door closed.** Nobody may enter or pass through. Tell the household the night
  before — a family member walking in is an immediate revocation risk.
- **Desk completely clear.** No paper, no pens, no notes, no Post-its, no tissue box, no food. A
  drink is allowed only in a **transparent, unlabelled** container.
- **One display.** Unplug and turn away any second monitor; switch off other computers in the room.
- **No headphones or earbuds** — speakers and mic must work. No watch, no smartwatch, no hat or
  hood, no jacket.
- **Your phone is REQUIRED for check-in, then goes away.** Verified 2026-09-14 and not in the
  earlier version of this file: *"Mobile phone photos must be uploaded to launch your exam."* You
  use the phone to capture and upload your **headshot, your ID and the room scan** — **the exam
  will not launch without them.** Charge it tonight.
- **Once check-in is done**, the phone goes out of arm's reach — floor behind you, another table —
  ringer on, with **+91 on your Learn profile** so the proctor can call. Do not touch it again,
  including during a break.
- **Sessions use facial comparison against your ID photo and AI-assisted monitoring**, and
  **using any AI tool during the exam is explicitly prohibited.**
- You will take **four room photos, a headshot and ID photos** at check-in, and may be asked for a
  **360° room scan** at check-in or mid-exam.

### 4.4 The machine

- **Local administrator rights** — this is the actual requirement. **Corrected 2026-09-14:** the
  machine does **not** have to be personally owned; Microsoft only *recommends* a personal over a
  work machine. **Do not migrate laptops on Thursday night** — a familiar machine that has passed
  the system test beats an unfamiliar "compliant" one.
- **Not a virtual machine.** Add an antivirus/firewall exception for the **OnVUE Secure Browser
  executable**, and make sure there is **no proxy or packet inspection** on the line. Those three
  are what actually block the launch.
- **Disconnect every VPN.** Close every application — OnVUE force-closes them and that can crash
  the launch and forfeit the fee.
- **Wired Ethernet if possible**; at least 6 Mbps down / 2 Mbps up. Ask the household not to stream.
- **Plug in the power cord.** Pause antivirus real-time scanning.
- **Run the system test Thursday and again Friday morning**, on the same machine, network and room.

### 4.45 Five failure modes nobody plans for

From the verification pass, ranked by how likely they are to actually bite:

**1. Indian passport name rendering.** This is *the* classic OnVUE India failure. Passports
frequently render the name as **SURNAME then GIVEN NAME**, or carry a single-field name, or expand
an initial that your Microsoft Learn profile abbreviates. **Put the passport physically beside the
certification profile and compare character by character** — not "does it look like me", but does
the *first name field* and the *last name field* match. This is the one with a deadline
(Pearson VUE, ~Tue 15 Sep).

**2. No backup connectivity.** Hyderabad, 07:00, single home line. **Charge a phone and test a
mobile hotspot against the OnVUE system test once this week**, so the fallback is known-good rather
than improvised at 07:05.

**3. The bathroom.** A 100-minute paper at 07:30 with morning coffee. The plan says take no break —
correct — but if you need one, it costs you every question you have already seen, not just the
clock. **Manage the input, not the urge.**

**4. Licence-tier blindness.** You have worked in E5 tenants for five years and your trial was E5
until 10 September, so **every feature you have ever touched was available to you.** The exam asks
which SKU a feature needs. Free vs P1 vs P2 vs Governance vs Entra Suite is a real answer category
and your instinct has no data on it — see [`PRACTITIONER-TRAPS.md`](PRACTITIONER-TRAPS.md).

**5. Sleep.** A 07:30 start means awake and sharp by 06:30. The timestamps on these files say you
were working at 03:05 on Monday. **Thursday's 17:00 stop exists because of that**, and it is the
instruction in this pack most likely to be ignored.

---

### 4.5 Friday morning — the timeline

```
06:30  Up. Eat something. A 100-minute exam on an empty stomach is a self-inflicted handicap.
06:45  Room staged. Desk clear. Second monitor unplugged. VPN off. Phone across the room.
06:50  System test, final run.
06:55  Seated.
07:00  START CHECK-IN.   <- the window is 30 min before to 15 min after. Check-in itself takes ~15 min.
07:30  Exam.
```

**Missing the check-in window is a no-show with no refund.** The hard cutoff for a 07:30 start is
**07:45**. Starting at 07:00 gives you thirty minutes of margin on a process that routinely takes
fifteen and takes longer on a slow machine.

**Also verified:** any reschedule made **inside 24 hours** forfeits the fee, and Microsoft requires
you to be a legitimate resident of the country you sit in.

**Read nothing new on Friday.** `GAP-DRILL.md` §8 — the ten one-liners — and the DISCRIMINATORS
tells. That is all.

---

## 5. Exam technique — the rules that are specific to this paper

**Format, verified:** 100 minutes of exam time, 120 minutes of seat time, typically **40–60
questions**, **700 of 1000 scaled** to pass, **no penalty for guessing**. Answer everything.

### 5.1 The three places you cannot go back — this is the big one

| | |
|---|---|
| **Problem-solution "Yes/No" sets** | *"Does this solution meet the goal?"* — once answered you **cannot return**, and they never appear on the review screen. **The solutions are independent: more than one can be Yes, and it is also possible that none of them is.** Two decision rules, verified: a solution that only *partially* solves the problem, or is merely the *first step*, is a **No**. And judge against *"does it meet the stated goal"*, never *"is this how I would build it"* — see [`PRACTITIONER-TRAPS.md`](PRACTITIONER-TRAPS.md) #20. **Never leave one blank; guess.** |
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
>
> **Two mechanics worth knowing:** no extra time is added, and **Ctrl+F searches inside the Learn
> pane only — not the exam question.**

**One more break restriction:** you **cannot start a break in the middle of a problem-solution set**
(or a lab) — only before or after one.

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

**It has now been adversarially verified, and two published claims failed.** The skeptic pass ran
on 2026-09-14. The **P2 trial** was refuted 3/3 and is removed. The **ID-exception rule** was
refuted 3/3 — it is Pearson VUE at three business days, not Microsoft at five — and that correction
turned an "already too late" into an action you can still take. The **D4 discriminators**, which I
hand-wrote when the first agent died, were fact-checked at **8 confirmed / 9 imprecise / 0 wrong**
and have been replaced with a verified set; the corrections are listed at the end of
[`DISCRIMINATORS.md`](DISCRIMINATORS.md).

> **Related:** [`PRACTITIONER-TRAPS.md`](PRACTITIONER-TRAPS.md) — **read this Thursday** ·
> [`BLIND-SPOTS.md`](BLIND-SPOTS.md) — three uncovered skill groups ·
> [`DISCRIMINATORS.md`](DISCRIMINATORS.md) — 83 pairs with exam tells ·
> [`GAP-DRILL.md`](GAP-DRILL.md) · [`EXPLAIN/`](EXPLAIN/) ·
> [`sc-300-lexicon.html`](sc-300-lexicon.html) — 274 terms, 83 traps flagged

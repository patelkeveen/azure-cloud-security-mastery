# Exam countdown — SC-300 on Friday 28 August 2026

> ⭐ **This file overrides the pacing in [`README.md`](README.md) §4.** That sprint was built to
> produce a portfolio on a 30-day licence clock. **You now have an exam in 8 days.** Those are
> different goals and they need different triage.
> **Written 2026-08-20. Exam 2026-08-28.**

---

## 1. ⭐ The arithmetic, stated honestly

You started **Wed 19 Aug** (Day 1). Days 2–7 as written are **~42 hours of labs**. Six days
remain before revision has to start. That is 7 h/day of labs and **zero hours of revision** —
and revision is what the exam actually rewards.

```
Aug 19 Wed   Day 1   DONE (telemetry incomplete - see sec.2)
Aug 20 Thu   Day 2   auth methods          <- TODAY
Aug 21 Fri   Day 3   Conditional Access    <- the heaviest exam day
Aug 22 Sat   Day 4   PIM and roles
Aug 23 Sun   Day 5   governance
Aug 24 Mon   Day 6   apps and workload identity
Aug 25 Tue   Day 7   external ID + Identity Protection
Aug 26 Wed   REVISION A   full drill pass + the sprint's blind spots
Aug 27 Thu   REVISION B   weak areas only, then stop early
Aug 28 Fri   EXAM
```

⭐ **It fits — but only because of the cut in section 3.**

---

## 2. ⚠ Day 1 is not finished. Fix this before anything else today

**Unified audit logging is genuinely OFF**, and the error message you hit sends you the wrong way.

Microsoft Learn (`purview/audit-log-enable-disable`, rev 2026-06-19):

> ⭐ *"unmanaged tenants that use free trials of enterprise licenses don't have auditing enabled
> by default … you must manually enable auditing."*

⭐ **So your `False` reading is true, not the stale-property artifact.** (That artifact is a
*different* trap worth knowing: in **Security & Compliance PowerShell** the property reads `False`
even when auditing is on. Read it in **Exchange Online PowerShell** or the answer is meaningless.
You did — so yours is real.)

The PowerShell path is a dead end on this tenant: the proxy throws
`InvalidOperationInDehydratedContextException` telling you to run
`Enable-OrganizationCustomization`, while `Get-OrganizationConfig` reports `IsDehydrated: False`
and `Enable-OrganizationCustomization` reports *"already enabled"*. ⭐ **Stop fighting it. Use the
portal — it is the documented path, not a workaround:**

```
1. https://purview.microsoft.com
2. Audit card   (or: View all solutions > Core > Audit)
3. Click the banner: "Start recording user and admin activity"
```

⭐ **Needs the *Audit Logs* role in Exchange Online** — the `Organization Management` or
`Compliance Management` role group. Global Admin alone does not always carry it.

Then **prove it**, because a flag records intent and only a search records capture:

```powershell
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -ResultSize 5
```

⚠ **Allow up to 60 minutes.** Zero rows after an hour means it is still off.

⭐ **Do this in the first ten minutes of today.** Audit captures **forward only** — it cannot
backfill 19 August, and Day 7's Identity Protection labs read the history this produces.

**Also from Day 1, still outstanding:** the six portal items in
`Day1-Enable-Telemetry.ps1` §3. ⭐ **Only two matter for the exam** — Identity Protection (already
on, good) and sign-in volume. Defender onboarding and attack simulation are SC-200. **Skip them
until 29 August.**

---

## 3. ⭐ The cut — what to stop doing, and why it costs you nothing

⭐ **The daily contract in [`README.md`](README.md) §5 has six steps. Steps 4–6 score zero exam
marks.**

```
[] Read the topic README first      <- KEEP, this is the revision
[] Run the lab                       <- KEEP
[] Break something deliberately      <- KEEP (see below)
[] File evidence with New-LabEvidence.ps1   <- DEFER to 29 Aug
[] Re-run Build-CoverageRegister.ps1        <- DEFER to 29 Aug
[] Commit                                   <- DEFER to 29 Aug
```

⭐ **This is not abandoning the evidence goal — it is sequencing it.** The tenant keeps its
configuration. Exports, screenshots and policy JSON can all be captured on **29 August–9
September**, which is still inside the E5 trial (expires **2026-09-10**). The exam cannot be
moved; the evidence sweep can.

⚠ **One exception, and it is genuinely irreversible: capture the verbatim error text from every
deliberate failure, in the moment.** Two minutes into a scratch file. Error strings are the one
artifact you cannot reconstruct next week, and
[`00-foundations/troubleshooting-method`](../00-foundations/troubleshooting-method/) is built on
recognising them.

```powershell
# The whole ceremony, compressed to something you will actually do
"$(Get-Date -f 'MM-dd HH:mm') | LAB 3.3 | $($Error[0].Exception.Message)" |
    Add-Content .\SC-300-SPRINT\evidence\errors-verbatim.log
```

⭐ **Saves ~6 hours across six days. That is exactly the revision time you need.**

---

## 4. Per-day triage — do the CORE, skip the rest until 29 August

**CORE** = the exam tests this · **TRIM** = configure it, skip the write-up ·
**DEFER** = after 28 August

| Day | CORE — do these | TRIM | DEFER |
|---|---|---|---|
| **2** Thu 20 | 2.2 TAP · 2.3 method ladder · 2.4 auth strengths · 2.5 SSPR + registration campaign | 2.6 legacy auth *(cause the failure, log the error, move on)* | 2.1 before/after measurement |
| **3** Fri 21 | ⭐ 3.1 policy set · 3.2 What-If · 3.3 the AND trap · 3.5 CAE | 3.4 token lifetime · 3.6 move to enforce | — |
| **4** Sat 22 | 4.2 the 2×2 · 4.3 activate with approval · 4.4 PIM for Groups · 4.5 service principals | deliberate failures *(log errors only)* | 4.1 standing-privilege measurement |
| **5** Sun 23 | ⭐ 5.1 access review **first** · 5.2 entitlement management · 5.3 lifecycle workflows | the "review that changes nothing" failure | — |
| **6** Mon 24 | 6.1 read a token · 6.2 delegated vs application · 6.3 consent framework | 6.4 workload identity federation | — |
| **7** Tue 25 | 7.1 Identity Protection · 7.3 external identities | 7.2 risk policies to enforce | ⭐ **7.4 evidence sweep · 7.5 rehearse expiry — 4 h, zero marks** |

⭐ **Day 3 has no DEFER row on purpose.** Conditional Access is the largest single block of marks
on this exam and the day is already the tightest. Protect it.

⚠ **Day 5's access review still runs first thing in the morning.** It needs elapsed time to
produce a result — that constraint is real regardless of exam pressure.

---

## 5. ⭐ The evening block — 90 minutes, every day, non-negotiable

⭐ **This is the part that was missing, and it is the part that passes exams.** Labs build
capability; the exam tests *recall under time pressure* and *discrimination between options that
look alike*. Those are trained separately.

```
20 min   Yesterday's material, cold. Cover the answer, say it out loud.
40 min   Today's drill from GAP-DRILL.md
20 min   RETENTION.md sec.4 confusion pairs + sec.6 symptom-to-cause
10 min   Write down every "and then it sort of..." you said. That list is tomorrow's 20 min.
```

| Evening of | Drill |
|---|---|
| Thu 20 | [`GAP-DRILL.md`](GAP-DRILL.md) §1 administrative units · §2 least-privilege roles |
| Fri 21 | §3 hybrid identity — PHS vs PTA vs federation ⭐ *(pure theory; you have no DC and do not need one)* |
| Sat 22 | §4 groups, licensing, dynamic rules |
| Sun 23 | §5 entitlement management — connected organizations |
| Mon 24 | §6 consent, permissions, and the `scp`/`roles` split |
| Tue 25 | §7 external identities — cross-tenant access and B2B direct connect |

---

## 6. Revision A — Wednesday 26 August

⭐ **No new material. None.** Anything unlearned by tonight stays unlearned.

```
09:00  GAP-DRILL.md end to end, cold, answers covered          2.5 h
12:00  RETENTION.md sec.1 numbers, sec.4 pairs, sec.6 reflexes 1.5 h
14:00  Microsoft Learn practice assessment, full and timed     1 h
15:00  Score it. Write down every wrong answer AND WHY.        1 h
16:30  Re-read only the topics behind the wrong answers        2 h
```

⭐ **The "and why" is the whole exercise.** A wrong answer you cannot explain will be wrong
again. Sort your errors into three buckets — *didn't know it* (go read), *knew it and misread the
question* (a technique problem, see [`EXAM-DAY.md`](EXAM-DAY.md)), *knew it and second-guessed
myself* (stop doing that; first instinct on recall questions is usually right).

⭐ **Free and official:** the practice assessment on the
[SC-300 exam page](https://learn.microsoft.com/credentials/certifications/exams/sc-300/). Take it
here, not on exam eve — you want time to act on the result.

---

## 7. Revision B — Thursday 27 August, and stop early

```
09:00  Only the weak areas from yesterday's scoring          3 h
12:00  Second practice pass, timed                           1 h
14:00  90-second refresher: RETENTION.md sec.9               0.5 h
15:00  Read EXAM-DAY.md once                                 0.5 h
16:00  ⭐ STOP. Confirm exam logistics. Do something else.
```

⭐ **Stopping at 16:00 is a technique, not a reward.** Cramming on exam eve reliably costs more
in fatigue than it adds in recall, and the last thing you read is the thing most likely to
crowd out something you already knew.

⚠ **Confirm before you close the laptop:** booking time and time zone, ID that matches the
booking name exactly, and — if it is an online proctored sit — the room and system check. **The
system check fails often enough that discovering it at the start of the exam is a real risk.**

---

## 8. What this plan does not pretend

⭐ **It does not make you good at hybrid identity.** You have no domain controller, so PHS, PTA,
federation, Entra Connect and password writeback are **theory only** — [`GAP-DRILL.md`](GAP-DRILL.md)
§3 gets you to exam-answerable, not to competent. ⭐ **Say that out loud in an interview and it
lands as judgement; imply otherwise and it collapses on the first follow-up.**

⭐ **It does not produce the portfolio.** WRITTEN stays **0/144** through 28 August by design.
The evidence sweep resumes 29 August with the trial still live until 10 September.

⭐ **It does not touch Azure — with one optional exception.** You have a subscription
(`912ac3b8-d003-48d1-8266-e4d029ba1fd7`, RG `sc-300-lab-cin-rg-01`) and **₹19,130 of credit that
expires 2026-09-10 — the same day as the E5 trial.** ⚠ **Sentinel, Defender for Cloud and Foundry
are SC-200 and SC-500 — not one mark on SC-300.** **29 August.**

⭐ **The exception is a real domain controller**, because it is the only thing that converts §8's
"hybrid identity is theory only" into something you have actually seen:
[`35-active-directory-and-hybrid-identity/ad-ds/lab/`](../35-active-directory-and-hybrid-identity/ad-ds/lab/).
Deploy + promote is **~90 minutes, mostly waiting**, and costs about **₹120**.

> ⭐ **Optional, Day 6 evening only, and only if Day 6 finishes on time.** Hybrid is ~5–8% of the
> exam and it tests the *decision model*, not `Install-ADDSForest`. ⭐ **The full hybrid track
> belongs to 29 Aug – 10 Sep, when both clocks are still live.** If Day 6 runs long, skip it
> without guilt — Conditional Access is worth five times as much.

> ⭐ **Related:** [`GAP-DRILL.md`](GAP-DRILL.md) — what the sprint never covered ·
> [`EXAM-DAY.md`](EXAM-DAY.md) — technique and the morning of ·
> [`README.md`](README.md) — the original 30-day framing ·
> [`../RETENTION.md`](../RETENTION.md) — the memory layer ·
> [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — when a lab will not start
